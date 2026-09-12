const prisma = require('../config/database');
const { recalcularStatusPedido, cobrirValorTx } = require('./pagamentoService');
const { parseData, normalizarDatas } = require('../utils/parseData');
const formaPagamentoService = require('./formaPagamentoService');
const pdfService = require('./pdfService');
const emailService = require('./emailService');
const telegramService = require('./telegramService');
const logService = require('./logService');
const { formatarNumeroPedido } = require('../utils/numeroPedido');
const { retryColisao } = require('../utils/retryColisao');
const BusinessError = require('../utils/BusinessError');

// Campos de pagamento retornados ao montar um pedido completo (listar/buscar).
const PAGAMENTO_SELECT = {
    id: true,
    valor_pago: true,
    data_pagamento: true,
    forma_pagamento: true,
    parcelas: true,
    conta: true,
    nome_pagador: true,
    cpf_cnpj_pagador: true,
    status_nota: true,
    numero_nota: true,
    data_emissao_nota: true,
    escambo_quantidade: true,
    criado_em: true,
    cheques: {
        select: {
            id: true,
            numero: true,
            banco: true,
            agencia: true,
            conta_corrente: true,
            valor: true,
            bom_para: true,
            data_deposito: true,
            depositado: true,
        },
    },
};

// Include padrão de um pedido completo: cliente, itens (com nome do produto),
// pagamentos (PAGAMENTO_SELECT) e entregas com seus itens.
const PEDIDO_INCLUDE = {
    clientes: { select: { id: true, nome: true, email: true } },
    itens_pedido: {
        include: { produtos: { select: { nome: true } } }
    },
    pagamentos: {
        select: PAGAMENTO_SELECT,
        orderBy: { criado_em: 'asc' }
    },
    entregas: {
        include: { itens_entrega: true }
    }
};

// Próximo número sequencial dentro de uma temporada (MAX + 1). Robusto para a
// importação de dados (continua a partir do maior número já usado) e para
// reativar uma temporada anterior (não duplica). `client` pode ser o prisma ou
// um cliente de transação (tx).
const proximoNumeroTemporada = async (client, ano) => {
    const agg = await client.pedidos.aggregate({
        _max: { numero_temporada: true },
        where: { temporada_ano: ano },
    });
    return (agg._max.numero_temporada ?? 0) + 1;
};

// Quando um update troca a temporada do pedido, recomputa o numero_temporada
// (próximo da nova temporada). Muta `campos` ajustando temporada_ano/numero_temporada.
const aplicarTrocaTemporada = async (client, id, campos) => {
    if (campos.temporada_ano === undefined) return;

    const atual = await client.pedidos.findUnique({
        where: { id: parseInt(id) },
        select: { temporada_ano: true },
    });

    const novoAno = campos.temporada_ano === null ? null : parseInt(campos.temporada_ano);
    campos.temporada_ano = novoAno;

    if (novoAno === atual?.temporada_ano) return; // sem mudança de temporada
    campos.numero_temporada = novoAno === null
        ? null
        : await proximoNumeroTemporada(client, novoAno);
};

// Cria o pedido dentro de uma transação já aberta pelo chamador (`tx`) — usado
// tanto por `criarPedido` (abre sua própria transação) quanto por
// `orcamentoService.aprovarOrcamento` (reaproveita a transação da aprovação).
// `dados.pagamentos` (opcional) é a entrada — mesmo formato aceito por
// POST /pagamentos. Quando informado (mesmo que `[]`), o que não for coberto
// pela entrada é lançado automaticamente como crediário, na MESMA transação
// (ver pagamentoService.cobrirValorTx): nenhum pedido nasce sem pagamento.
// Omitir o campo (undefined) mantém o comportamento antigo — pedido sem
// nenhum pagamento — para quem não usa esse fluxo (ex.: fábricas de teste).
const criarPedidoTx = async (tx, dados, usuarioId = null) => {
    // O número de temporada vem da temporada ativa (configurada no Admin).
    // Sem temporada ativa, o pedido fica sem número (exibe '#id' como fallback).
    const temporada = await tx.temporadas.findFirst({ where: { ativo: true } });
    const temporada_ano = temporada?.ano ?? null;
    const numero_temporada = temporada
        ? await proximoNumeroTemporada(tx, temporada.ano)
        : null;

    // valor_total é sempre recalculado a partir dos itens (não confia no cliente),
    // mesma lógica usada no branch com itens de atualizarPedido.
    const subtotal = dados.itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );
    const ajuste = Number(dados.ajuste ?? 0);

    const pedido = await tx.pedidos.create({
        data: {
            clientes: {
                connect: { id: parseInt(dados.cliente_id) }
            },
            valor_total: subtotal + ajuste,
            ajuste: dados.ajuste ?? null,
            observacoes: dados.observacoes,
            // Na criação, a data do pedido é o momento atual (= criado_em).
            // Pode ser alterada depois na consulta (PUT /pedidos/:id).
            data_pedido: parseData(dados.data_pedido, 'data_pedido') ?? new Date(),
            status_geral: 'Ativa',
            ativo: true,
            temporada_ano,
            numero_temporada,

            itens_pedido: {
                create: dados.itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: item.valor_unitario
                }))
            }
        },
        // Mesmo formato de itens usado no snapshot de atualização (com
        // produtos.nome) — sem isso, o diff de histórico compararia itens
        // com/sem essa chave e marcaria todo item como "alterado" só por
        // causa da forma do JSON, não do conteúdo.
        include: {
            itens_pedido: {
                include: { produtos: { select: { nome: true } } }
            }
        }
    });

    if (Array.isArray(dados.pagamentos)) {
        const formasPosteriores = await formaPagamentoService.listarPosteriores(tx);
        await cobrirValorTx(
            tx,
            { pedidoId: pedido.id, valorAlvo: pedido.valor_total },
            dados.pagamentos,
            formasPosteriores,
            usuarioId
        );
    }

    await logService.registrarAtividade(tx, {
        usuarioId,
        acao: 'criacao',
        entidade: 'pedido',
        entidadeId: pedido.id,
        snapshot: pedido,
    });

    return pedido;
};

// Duas criações concorrentes na mesma temporada podem calcular o mesmo
// próximo numero_temporada antes de qualquer uma gravar — a constraint única
// (schema.prisma) rejeita a segunda com P2002. retryColisao tenta de novo
// (recalculando o número dentro de uma nova transação) em vez de propagar
// um 500 por uma corrida que se resolve sozinha na repetição.
const criarPedido = async (dados, usuarioId = null) => {
    const pedido = await retryColisao(() => prisma.$transaction((tx) => criarPedidoTx(tx, dados, usuarioId)));

    // recalcularStatusPedido lê via `prisma` direto (não `tx`), então só pode
    // rodar depois que a transação já commitou. Sem isso, um pagamento real
    // registrado na criação nunca marcaria o pedido como Pago/Parcial (o
    // valor padrão do banco para status_pagamento é Pendente).
    // Em try/catch de propósito: o pedido JÁ FOI criado (com itens e
    // pagamentos) nesse ponto — se essa chamada falhar (ex.: instabilidade
    // transitória de conexão), propagar o erro devolveria um 500 pra uma
    // operação que já teve sucesso, e o operador tentando de novo criaria um
    // pedido duplicado (POST /pedidos não tem trava de idempotência). Pior
    // consequência de só logar: status_pagamento fica desatualizado até a
    // próxima edição/pagamento recalcular — não perde dinheiro nem duplica.
    if (Array.isArray(dados.pagamentos)) {
        try {
            await recalcularStatusPedido(pedido.id, usuarioId);
        } catch (erro) {
            console.error(`Falha ao recalcular status do pedido ${pedido.id} (já criado com sucesso):`, erro);
        }
    }

    return pedido;
};

// Status da nota fiscal do pedido, agregado a partir dos pagamentos reais
// (crediário/"a receber" não conta — ainda não há nota). Mesma regra do front
// (lista_pedidos.dart). Prioridade: Rejeitada > Processando > Emitida (todas) >
// Parcial (algumas) > Pendente. Recebe os pagamentos já com a flag pagamento_posterior.
const statusNotaPedido = (pagamentos) => {
    const reais = pagamentos.filter(p => p.pagamento_posterior !== true);
    if (reais.length === 0) return 'Pendente';

    const statuses = reais.map(p => p.status_nota ?? 'Pendente');
    if (statuses.includes('Rejeitada')) return 'Rejeitada';
    if (statuses.includes('Processando')) return 'Processando';

    const emitidas = statuses.filter(s => s === 'Emitida').length;
    if (emitidas === 0) return 'Pendente';
    if (emitidas === statuses.length) return 'Emitida';
    return 'Parcial';
};

const listarPedidos = async (filtros = {}) => {
    const where = { ativo: true };
    // Filtrar por id é o correto quando se sabe de qual cliente se trata (ex.:
    // a ficha do cliente). Por nome, `contains` traz homônimos junto — "Ana"
    // devolve pedidos de "Ana Maria" e "Mariana".
    if (filtros.clienteId) {
        where.cliente_id = parseInt(filtros.clienteId);
    } else if (filtros.cliente) {
        where.clientes = { nome: { contains: filtros.cliente } };
    }
    // Filtra por status de entrega (ex.: 'Pendente,Parcial') quando informado
    if (filtros.statusEntrega) {
        where.status_entrega = { in: filtros.statusEntrega.split(',') };
    }
    // Filtra por status de pagamento (ex.: 'Pendente,Parcial') quando informado
    if (filtros.statusPagamento) {
        where.status_pagamento = { in: filtros.statusPagamento.split(',') };
    }
    // Intervalo de datas (criado_em) — obrigatório no front (padrão: última semana).
    if (filtros.de || filtros.ate) {
        where.criado_em = {
            ...(filtros.de && { gte: new Date(filtros.de) }),
            ...(filtros.ate && { lte: new Date(filtros.ate) }),
        };
    }
    if (filtros.temporadaAno) {
        where.temporada_ano = { in: filtros.temporadaAno.split(',').map(Number) };
    }
    if (filtros.formaPagamento) {
        where.pagamentos = { some: { forma_pagamento: { in: filtros.formaPagamento.split(',') } } };
    }
    if (filtros.numero) {
        // Aceita os formatos exibidos por formatarNumeroPedido: "AA-N" (ex. "26-1",
        // temporada+número) ou só "N" (número da temporada, sem precisar informar a
        // safra — busca em qualquer uma). "#id" busca pelo id bruto, só usado no
        // fallback de pedidos sem temporada (exibidos como "#id").
        const bruto = filtros.numero.trim();
        if (bruto.startsWith('#')) {
            const idStr = bruto.slice(1);
            where.id = /^\d+$/.test(idStr) ? parseInt(idStr) : -1;
        } else {
            const match = bruto.match(/^(\d{1,2})-(\d+)$/);
            if (match) {
                where.temporada_ano = 2000 + parseInt(match[1]);
                where.numero_temporada = parseInt(match[2]);
            } else if (/^\d+$/.test(bruto)) {
                where.numero_temporada = parseInt(bruto);
            } else {
                // Formato incompleto/inválido (usuário ainda digitando) — nenhum resultado.
                where.id = -1;
            }
        }
    }

    const [pedidos, formasPosteriores] = await Promise.all([
        prisma.pedidos.findMany({
            where,
            orderBy: [{ data_pedido: 'desc' }, { criado_em: 'desc' }],
            include: PEDIDO_INCLUDE
        }),
        formaPagamentoService.listarPosteriores()
    ]);

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));

    // Adiciona flag pagamento_posterior em cada pagamento
    const comFlag = pedidos.map(pedido => ({
        ...pedido,
        pagamentos: pedido.pagamentos.map(pag => ({
            ...pag,
            pagamento_posterior: nomesPosteriores.has(pag.forma_pagamento)
        }))
    }));

    // Filtra por status de nota (agregado dos pagamentos reais) — feito em memória,
    // pois a nota não é uma coluna do pedido.
    if (filtros.statusNota) {
        const alvo = new Set(filtros.statusNota.split(','));
        return comFlag.filter(p => alvo.has(statusNotaPedido(p.pagamentos)));
    }
    return comFlag;
};

// Campos editáveis via PUT /pedidos/:id quando o body não envia itens (ex.:
// só mudar a data ou a temporada). Fora daqui ficam campos que ou dependem
// de itens (ajuste, valor_total) ou são geridos por outros fluxos
// (status_pagamento, status_entrega, ativo, cliente_id, numero_temporada).
const CAMPOS_PEDIDO_SEM_ITENS = ['data_pedido', 'temporada_ano', 'observacoes'];

const atualizarPedido = async (id, dados, usuarioId = null) => {
    const { itens, pagamentos, ...camposBrutos } = dados;
    const camposPedido = normalizarDatas(camposBrutos, ['data_pedido']);

    if (!itens) {
        // Edição de metadados (sem itens) continua liberada mesmo com o pedido
        // fechado (pago + entregue) — só a edição de itens é bloqueada nesse
        // caso (ver branch abaixo). A trava aqui é só a whitelist de campos.
        const camposPermitidos = Object.fromEntries(
            Object.entries(camposPedido).filter(([chave]) => CAMPOS_PEDIDO_SEM_ITENS.includes(chave))
        );

        return await prisma.$transaction(async (tx) => {
            await aplicarTrocaTemporada(tx, id, camposPermitidos);
            // Mesmo formato de itens usado nas demais snapshots de pedido —
            // sem isso, o diff de histórico não teria como comparar
            // itens_pedido contra este evento (campo ausente = comparação
            // pulada), mesmo o pedido não tendo mudado de itens aqui.
            const resultado = await tx.pedidos.update({
                where: { id: parseInt(id) },
                data: camposPermitidos,
                include: { itens_pedido: { include: { produtos: { select: { nome: true } } } } },
            });
            await logService.registrarAtividade(tx, {
                usuarioId,
                acao: 'atualizacao',
                entidade: 'pedido',
                entidadeId: resultado.id,
                snapshot: resultado,
            });
            return resultado;
        });
    }

    const [pedidoAtual, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(id) },
            select: {
                ajuste: true,
                cliente_id: true,
                valor_total: true,
                status_pagamento: true,
                status_entrega: true,
                pagamentos: { select: { valor_pago: true, forma_pagamento: true } },
            },
        }),
        formaPagamentoService.listarPosteriores(),
    ]);

    const pagamentoFechado = pedidoAtual?.status_pagamento === 'Pago' || pedidoAtual?.status_pagamento === 'Crédito';
    const entregaFechada = pedidoAtual?.status_entrega === 'Entregue';
    if (pagamentoFechado && entregaFechada) {
        throw new BusinessError('Este pedido já foi pago e entregue integralmente e não pode mais ser alterado.');
    }

    // Caso o update também troque a temporada (raro nesta ramificação), recomputa o número.
    await aplicarTrocaTemporada(prisma, id, camposPedido);

    const ajuste = camposPedido.ajuste !== undefined
        ? Number(camposPedido.ajuste ?? 0)
        : Number(pedidoAtual?.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const totalPagoReal = (pedidoAtual?.pagamentos ?? [])
        .filter(p => !nomesPosteriores.has(p.forma_pagamento))
        .reduce((s, p) => s + parseFloat(p.valor_pago), 0);
    // Real + crediário — usado só para medir o aumento (abaixo), diferente de
    // totalPagoReal (só real), usado no cálculo de crédito/estorno.
    const totalCobertoTudo = (pedidoAtual?.pagamentos ?? [])
        .reduce((s, p) => s + parseFloat(p.valor_pago), 0);

    const novoTotal = subtotal + ajuste;
    // Quanto o aumento do pedido ainda não tem cobertura — só positivo quando
    // o novo total supera o que já estava pago/creditariado antes da edição.
    const aCobrir = novoTotal - totalCobertoTudo;

    // O crédito do cliente por causa deste pedido é sempre a sobra atual
    // (pago real - total), não um incremento por edição. Creditar
    // `totalPagoReal - novoTotal` direto duplicava a mesma sobra a cada nova
    // edição, porque os pagamentos não são reduzidos ao conceder o crédito.
    // Aqui move-se só a diferença entre a sobra de antes e a de agora — o que
    // também estorna o crédito quando o pedido volta a subir de valor.
    const totalAnterior = Number(pedidoAtual?.valor_total ?? 0);
    const sobraAnterior = Math.max(0, totalPagoReal - totalAnterior);
    const sobraAtual = Math.max(0, totalPagoReal - novoTotal);
    const creditoGerado = sobraAtual - sobraAnterior;

    let resultado;
    await prisma.$transaction(async (tx) => {
        if (Math.abs(creditoGerado) > 0.01 && pedidoAtual?.cliente_id) {
            const cliente = await tx.clientes.findUnique({
                where: { id: pedidoAtual.cliente_id },
                select: { saldo_credito: true },
            });
            // Estorno nunca deixa o saldo negativo — dados anteriores a esta
            // correção podem ter crédito inflado ou já consumido.
            const saldoAtual = Number(cliente?.saldo_credito ?? 0);
            const delta = Math.max(creditoGerado, -saldoAtual);

            if (Math.abs(delta) > 0.01) {
                const clienteAtualizado = await tx.clientes.update({
                    where: { id: pedidoAtual.cliente_id },
                    data: { saldo_credito: { increment: delta } },
                });
                // Saldo do cliente mudando sem log nenhum — só dava pra ver o
                // valor atual, nunca por que/quando mudou.
                await logService.registrarAtividade(tx, {
                    usuarioId,
                    acao: 'atualizacao_automatica',
                    entidade: 'cliente',
                    entidadeId: clienteAtualizado.id,
                    snapshot: clienteAtualizado,
                });
            }
        }

        await tx.itens_pedido.deleteMany({ where: { pedido_id: parseInt(id) } });

        resultado = await tx.pedidos.update({
            where: { id: parseInt(id) },
            data: {
                ...camposPedido,
                valor_total: novoTotal,
                itens_pedido: {
                    create: itens.map(item => ({
                        produto_id: parseInt(item.produto_id),
                        quantidade: parseInt(item.quantidade),
                        valor_unitario: parseFloat(item.valor_unitario),
                    })),
                },
            },
            include: {
                itens_pedido: {
                    include: { produtos: { select: { nome: true } } },
                },
            },
        });

        // `pagamentos` (opcional) é a entrada informada pro aumento do
        // pedido — mesmo formato de POST /pagamentos. O que não for coberto
        // vira crediário automático, dentro da MESMA transação da edição
        // (ver pagamentoService.cobrirValorTx). Sem isso, o app antes fazia
        // isto em chamadas soltas depois do PUT já ter persistido — se a
        // rede caísse no meio, o aumento ficava sem nenhum pagamento.
        if (Array.isArray(pagamentos) && aCobrir > 0.005) {
            await cobrirValorTx(
                tx,
                { pedidoId: parseInt(id), valorAlvo: aCobrir },
                pagamentos,
                formasPosteriores,
                usuarioId
            );
        }

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao',
            entidade: 'pedido',
            entidadeId: resultado.id,
            snapshot: resultado,
        });
    });

    await recalcularStatusPedido(id, usuarioId);

    return { ...resultado, creditoGerado };
};

const buscarPedido = async (id) => {
    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(id), ativo: true },
            include: PEDIDO_INCLUDE
        }),
        formaPagamentoService.listarPosteriores()
    ]);

    if (!pedido) return null;

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    return {
        ...pedido,
        pagamentos: pedido.pagamentos.map(pag => ({
            ...pag,
            pagamento_posterior: nomesPosteriores.has(pag.forma_pagamento)
        }))
    };
};

const eliminarPedido = async (id, usuarioId = null) => {
    return await prisma.$transaction(async (tx) => {
        const pedido = await tx.pedidos.update({
            where: { id: parseInt(id) },
            data: { ativo: false },
            include: { itens_pedido: { include: { produtos: { select: { nome: true } } } } },
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'exclusao',
            entidade: 'pedido',
            entidadeId: pedido.id,
            snapshot: pedido,
        });
        return pedido;
    });
};

// Dispara as notificações de um evento de pedido — e-mail (administração e,
// conforme o evento, o cliente) e Telegram (administração). `evento` é uma
// chave de emailService.EVENTOS. O PDF é gerado uma única vez aqui e
// reaproveitado pelos dois canais; cada canal falha de forma independente e
// sem derrubar o outro nem o registro do pedido — notificação é best-effort.
// Silencioso quando o pedido não existe mais (ex.: apagado logo depois).
const notificarPedido = async (id, evento) => {
    let documento;
    try {
        documento = await pdfService.gerarPedidoPDF(id);
    } catch (erro) {
        if (erro.status === 404) return;
        console.error(`Falha ao gerar PDF para notificar o pedido ${id}:`, erro);
        return;
    }
    const numero = formatarNumeroPedido(documento.entidade);

    emailService.notificarEvento({ evento, documento, numero })
        .catch((erro) => console.error('Falha ao enviar notificação de e-mail do pedido:', erro));
    telegramService.notificarEvento({ evento, documento, numero })
        .catch((erro) => console.error('Falha ao enviar notificação de Telegram do pedido:', erro));
};

const enviarPedidoPorEmail = (id) => emailService.enviarDocumentoPorEmail({
    id,
    evento: 'pedidoManual',
    gerarPDF: pdfService.gerarPedidoPDF,
    formatarNumero: formatarNumeroPedido,
});

module.exports = {
    criarPedido,
    listarPedidos,
    buscarPedido,
    atualizarPedido,
    eliminarPedido,
    enviarPedidoPorEmail,
    notificarPedido,
    proximoNumeroTemporada,
    criarPedidoTx
};
