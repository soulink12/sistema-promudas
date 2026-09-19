const prisma = require('../config/database');
const { normalizarDatas } = require('../utils/parseData');
const pdfService = require('./pdfService');
const emailService = require('./emailService');
const telegramService = require('./telegramService');
const pedidoService = require('./pedidoService');
const pagamentoService = require('./pagamentoService');
const logService = require('./logService');
const { formatarNumeroOrcamento } = require('../utils/numeroOrcamento');
const { retryColisao } = require('../utils/retryColisao');
const BusinessError = require('../utils/BusinessError');

const ORCAMENTO_INCLUDE = {
    clientes: { select: { id: true, nome: true, email: true } },
    itens_orcamento: {
        include: { produtos: { select: { nome: true } } }
    }
};

// Próximo numero_temporada pra orçamentos de uma safra — mesmo padrão de
// pedidoService.proximoNumeroTemporada, mas contador próprio (coluna
// separada, mesmo nome) já que orçamento e pedido não compartilham sequência.
const proximoNumeroTemporadaOrcamento = async (client, ano) => {
    const agg = await client.orcamentos.aggregate({
        _max: { numero_temporada: true },
        where: { temporada_ano: ano },
    });
    return (agg._max.numero_temporada ?? 0) + 1;
};

// Cria o orçamento dentro de uma transação já aberta pelo chamador — usado
// por `criarOrcamento`, que abre a transação e envolve tudo em retryColisao
// (ver comentário lá) por causa da corrida no cálculo do numero_temporada.
const criarOrcamentoTx = async (tx, dados, usuarioId = null) => {
    // Número vem da temporada ativa (mesma configurada no Admin pra pedido).
    // Sem temporada ativa, o orçamento fica sem número (exibe '#id' como
    // fallback) — mesma regra de pedidoService.criarPedidoTx.
    const temporada = await tx.temporadas.findFirst({ where: { ativo: true } });
    const temporada_ano = temporada?.ano ?? null;
    const numero_temporada = temporada
        ? await proximoNumeroTemporadaOrcamento(tx, temporada.ano)
        : null;

    // valor_total é sempre recalculado a partir dos itens (não confia no
    // cliente), mesma lógica de pedidoService.criarPedidoTx.
    const subtotal = dados.itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );
    const ajuste = Number(dados.ajuste ?? 0);

    const orcamento = await tx.orcamentos.create({
        data: {
            clientes: {
                connect: { id: parseInt(dados.cliente_id) }
            },
            valor_total: subtotal + ajuste,
            ajuste: dados.ajuste ?? null,
            observacoes: dados.observacoes,
            data_orcamento: new Date(),
            status: 'Pendente',
            ativo: true,
            temporada_ano,
            numero_temporada,

            itens_orcamento: {
                create: dados.itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: item.valor_unitario
                }))
            }
        },
        // Mesmo formato de itens usado nas demais snapshots de orçamento
        // (ORCAMENTO_INCLUDE) — sem isso, o diff de histórico compararia
        // itens com/sem `produtos.nome` e marcaria todo item como
        // "alterado" só por causa da forma do JSON, não do conteúdo.
        include: {
            itens_orcamento: {
                include: { produtos: { select: { nome: true } } }
            }
        }
    });

    await logService.registrarAtividade(tx, {
        usuarioId,
        acao: 'criacao',
        entidade: 'orcamento',
        entidadeId: orcamento.id,
        snapshot: orcamento,
    });

    return orcamento;
};

// Duas criações concorrentes na mesma temporada podem calcular o mesmo
// próximo numero_temporada antes de qualquer uma gravar — a constraint única
// (schema.prisma) rejeita a segunda com P2002. retryColisao tenta de novo
// (recalculando o número dentro de uma nova transação), mesmo padrão de
// pedidoService.criarPedido.
const criarOrcamento = async (dados, usuarioId = null) => {
    return await retryColisao(() => prisma.$transaction((tx) => criarOrcamentoTx(tx, dados, usuarioId)));
};

const listarOrcamentos = async (filtros = {}) => {
    const where = { ativo: true };
    if (filtros.cliente) {
        where.clientes = { nome: { contains: filtros.cliente } };
    }
    if (filtros.status) {
        where.status = { in: filtros.status.split(',') };
    }
    if (filtros.de || filtros.ate) {
        where.criado_em = {
            ...(filtros.de && { gte: new Date(filtros.de) }),
            ...(filtros.ate && { lte: new Date(filtros.ate) }),
        };
    }
    if (filtros.numero) {
        // Aceita os formatos exibidos por formatarNumeroOrcamento: "O26-3" (ou
        // "26-3", sem o prefixo) para temporada+número, só "N" para o número
        // em qualquer temporada, ou "#id" pro fallback de orçamentos sem
        // temporada (exibidos como "#id") — mesmo padrão de
        // pedidoService.listarPedidos.
        const bruto = filtros.numero.trim();
        if (bruto.startsWith('#')) {
            const idStr = bruto.slice(1);
            where.id = /^\d+$/.test(idStr) ? parseInt(idStr) : -1;
        } else {
            const semPrefixo = bruto.replace(/^[Oo]/, '');
            const match = semPrefixo.match(/^(\d{1,2})-(\d+)$/);
            if (match) {
                where.temporada_ano = 2000 + parseInt(match[1]);
                where.numero_temporada = parseInt(match[2]);
            } else if (/^\d+$/.test(semPrefixo)) {
                where.numero_temporada = parseInt(semPrefixo);
            } else {
                // Formato incompleto/inválido (usuário ainda digitando) — nenhum resultado.
                where.id = -1;
            }
        }
    }

    return await prisma.orcamentos.findMany({
        where,
        orderBy: [{ data_orcamento: 'desc' }, { criado_em: 'desc' }],
        include: ORCAMENTO_INCLUDE
    });
};

const buscarOrcamento = async (id) => {
    return await prisma.orcamentos.findUnique({
        where: { id: parseInt(id), ativo: true },
        include: ORCAMENTO_INCLUDE
    });
};

// Edita um orçamento pendente (cliente, itens, ajuste, observações). Recalcula
// o valor_total a partir dos itens+ajuste, como a edição de pedido faz.
// Bloqueia edição de orçamento já aprovado/rejeitado.
const atualizarOrcamento = async (id, dados, usuarioId = null) => {
    const orcamentoAtual = await prisma.orcamentos.findUnique({
        where: { id: parseInt(id) },
        select: { status: true, ajuste: true },
    });
    if (!orcamentoAtual) {
        throw new BusinessError('Orçamento não encontrado.', 404);
    }
    if (orcamentoAtual.status !== 'Pendente') {
        throw new BusinessError('Este orçamento já foi aprovado ou recusado e não pode mais ser alterado.');
    }

    const { itens, ...camposBrutos } = dados;
    const camposOrcamento = normalizarDatas(camposBrutos, ['data_orcamento']);
    // Numeração é atribuída só na criação — nunca editável via PUT, mesmo que
    // o body envie esses campos (defesa, o frontend hoje não os manda).
    delete camposOrcamento.temporada_ano;
    delete camposOrcamento.numero_temporada;

    if (!itens) {
        return await prisma.$transaction(async (tx) => {
            const orcamento = await tx.orcamentos.update({
                where: { id: parseInt(id) },
                data: camposOrcamento,
                include: ORCAMENTO_INCLUDE,
            });
            await logService.registrarAtividade(tx, {
                usuarioId,
                acao: 'atualizacao',
                entidade: 'orcamento',
                entidadeId: orcamento.id,
                snapshot: orcamento,
            });
            return orcamento;
        });
    }

    const ajuste = camposOrcamento.ajuste !== undefined
        ? Number(camposOrcamento.ajuste ?? 0)
        : Number(orcamentoAtual.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    return await prisma.$transaction(async (tx) => {
        await tx.itens_orcamento.deleteMany({ where: { orcamento_id: parseInt(id) } });

        const orcamento = await tx.orcamentos.update({
            where: { id: parseInt(id) },
            data: {
                ...camposOrcamento,
                valor_total: subtotal + ajuste,
                itens_orcamento: {
                    create: itens.map(item => ({
                        produto_id: parseInt(item.produto_id),
                        quantidade: parseInt(item.quantidade),
                        valor_unitario: parseFloat(item.valor_unitario),
                    })),
                },
            },
            include: ORCAMENTO_INCLUDE,
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao',
            entidade: 'orcamento',
            entidadeId: orcamento.id,
            snapshot: orcamento,
        });

        return orcamento;
    });
};

const eliminarOrcamento = async (id, usuarioId = null) => {
    return await prisma.$transaction(async (tx) => {
        const orcamento = await tx.orcamentos.update({
            where: { id: parseInt(id) },
            data: { ativo: false },
            include: { itens_orcamento: { include: { produtos: { select: { nome: true } } } } },
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'exclusao',
            entidade: 'orcamento',
            entidadeId: orcamento.id,
            snapshot: orcamento,
        });
        return orcamento;
    });
};

// Aprova o orçamento: cria um Pedido de verdade com os mesmos dados (cliente,
// itens, ajuste, observações) e marca o orçamento como Aprovado, vinculado ao
// pedido criado. `dados.pagamentos` (opcional) é a entrada dada pelo cliente
// — mesmo formato aceito por POST /pagamentos — repassada direto pra
// criarPedidoTx, que cobre o que faltar automaticamente com crediário dentro
// da MESMA transação (ver pagamentoService.cobrirValorTx): nenhum pedido
// nasce sem pagamento, e se faltar forma de crediário cadastrada ou algum
// pagamento falhar a validação, a aprovação inteira desfaz — o orçamento
// continua Pendente, em vez de ficar aprovado com um pedido órfão.
// Mesma corrida de numero_temporada de pedidoService.criarPedido (a aprovação
// cria um pedido de verdade via criarPedidoTx) — retryColisao tenta de novo
// em vez de propagar um 500 por uma colisão que se resolve sozinha na repetição.
const aprovarOrcamento = async (id, dados = {}, usuarioId = null) => {
    const pagamentos = Array.isArray(dados.pagamentos) ? dados.pagamentos : [];

    const resultado = await retryColisao(() => prisma.$transaction(async (tx) => {
        const orcamento = await tx.orcamentos.findUnique({
            where: { id: parseInt(id) },
            include: { itens_orcamento: true },
        });
        if (!orcamento) {
            throw new BusinessError('Orçamento não encontrado.', 404);
        }
        if (orcamento.status !== 'Pendente') {
            throw new BusinessError('Este orçamento já foi aprovado ou recusado.');
        }

        const pedido = await pedidoService.criarPedidoTx(tx, {
            cliente_id: orcamento.cliente_id,
            valor_total: orcamento.valor_total,
            ajuste: orcamento.ajuste,
            observacoes: orcamento.observacoes,
            itens: orcamento.itens_orcamento.map(item => ({
                produto_id: item.produto_id,
                quantidade: item.quantidade,
                valor_unitario: item.valor_unitario,
            })),
            pagamentos,
        }, usuarioId);

        const orcamentoAprovado = await tx.orcamentos.update({
            where: { id: parseInt(id) },
            data: { status: 'Aprovado', pedido_id: pedido.id },
            include: ORCAMENTO_INCLUDE,
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'aprovacao',
            entidade: 'orcamento',
            entidadeId: orcamentoAprovado.id,
            snapshot: orcamentoAprovado,
        });

        return orcamentoAprovado;
    }));

    // recalcularStatusPedido lê pelo client Prisma "de fora" (não pelo `tx`),
    // então só pode rodar depois que a transação já commitou — mesmo padrão
    // de atualizarPedido/registrarPagamentosDoPedido. Sem isso, uma entrada em
    // dinheiro registrada aqui nunca marcaria o pedido como Pago/Parcial (o
    // valor padrão do banco para status_pagamento é Pendente).
    // Em try/catch de propósito: o orçamento JÁ FOI aprovado e o pedido JÁ
    // FOI criado nesse ponto — se essa chamada falhar, propagar o erro
    // devolveria um 500 pra uma aprovação que já teve sucesso, e como o
    // orçamento não está mais 'Pendente', uma nova tentativa falharia pra
    // sempre com "já foi aprovado ou recusado", sem nenhum jeito de corrigir
    // pela API. Pior consequência de só logar: status_pagamento fica
    // desatualizado até a próxima edição/pagamento recalcular.
    try {
        await pagamentoService.recalcularStatusPedido(resultado.pedido_id, usuarioId);
    } catch (erro) {
        console.error(`Falha ao recalcular status do pedido ${resultado.pedido_id} (orçamento já aprovado com sucesso):`, erro);
    }

    return resultado;
};

const recusarOrcamento = async (id, usuarioId = null) => {
    const orcamento = await prisma.orcamentos.findUnique({
        where: { id: parseInt(id) },
        select: { status: true },
    });
    if (!orcamento) {
        throw new BusinessError('Orçamento não encontrado.', 404);
    }
    if (orcamento.status !== 'Pendente') {
        throw new BusinessError('Este orçamento já foi aprovado ou recusado.');
    }
    return await prisma.$transaction(async (tx) => {
        const atualizado = await tx.orcamentos.update({
            where: { id: parseInt(id) },
            data: { status: 'Rejeitado' },
            include: { itens_orcamento: { include: { produtos: { select: { nome: true } } } } },
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'recusa',
            entidade: 'orcamento',
            entidadeId: atualizado.id,
            snapshot: atualizado,
        });
        return atualizado;
    });
};

// Dispara as notificações de um evento de orçamento — e-mail e Telegram, veja
// pedidoService.notificarPedido (mesmo formato, espelhado aqui pro orçamento).
// `evento` é uma chave de emailService.EVENTOS.
const notificarOrcamento = async (id, evento) => {
    let documento;
    try {
        documento = await pdfService.gerarOrcamentoPDF(id);
    } catch (erro) {
        if (erro.status === 404) return;
        console.error(`Falha ao gerar PDF para notificar o orçamento ${id}:`, erro);
        return;
    }
    const numero = formatarNumeroOrcamento(documento.entidade);

    emailService.notificarEvento({ evento, documento, numero })
        .catch((erro) => console.error('Falha ao enviar notificação de e-mail do orçamento:', erro));
    telegramService.notificarEvento({ evento, documento, numero })
        .catch((erro) => console.error('Falha ao enviar notificação de Telegram do orçamento:', erro));
};

const enviarOrcamentoPorEmail = (id) => emailService.enviarDocumentoPorEmail({
    id,
    evento: 'orcamentoManual',
    gerarPDF: pdfService.gerarOrcamentoPDF,
    formatarNumero: formatarNumeroOrcamento,
});

module.exports = {
    criarOrcamento,
    listarOrcamentos,
    buscarOrcamento,
    atualizarOrcamento,
    eliminarOrcamento,
    aprovarOrcamento,
    recusarOrcamento,
    enviarOrcamentoPorEmail,
    notificarOrcamento
};
