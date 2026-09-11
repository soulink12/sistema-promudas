const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { normalizarDatas } = require('../utils/parseData');
const formaPagamentoService = require('./formaPagamentoService');
const logService = require('./logService');

// Recalcula o status de pagamento do pedido com base na soma real dos pagamentos no banco.
// Pagamentos com forma de pagamento posterior (ex: crediário) não contam como valor recebido.
// `usuarioId` é repassado de quem disparou o recálculo (registrar/editar/excluir pagamento) —
// só gera uma entrada de log quando o status realmente muda, para não duplicar o evento que
// já foi logado por quem chamou.
const recalcularStatusPedido = async (pedido_id, usuarioId = null) => {
    const [pedido, formasPosteriores, formasDeposito] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(pedido_id) },
            include: { pagamentos: { include: { cheques: true } } }
        }),
        formaPagamentoService.listarPosteriores(),
        formaPagamentoService.listarDepositoPosterior()
    ]);

    if (!pedido) return;

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const nomesDeposito = new Set(formasDeposito.map(f => f.nome));

    // Só conta o que foi efetivamente recebido:
    // - crediário (pagamento posterior) não conta;
    // - cheque (depósito posterior) só conta a parte já depositada;
    // - demais formas contam o valor pago integral.
    const totalPago = pedido.pagamentos.reduce((soma, p) => {
        if (nomesPosteriores.has(p.forma_pagamento)) return soma;
        if (nomesDeposito.has(p.forma_pagamento)) {
            const depositado = (p.cheques || [])
                .filter(c => c.depositado)
                .reduce((a, c) => a + parseFloat(c.valor), 0);
            return soma + depositado;
        }
        return soma + parseFloat(p.valor_pago);
    }, 0);

    const valorTotal = parseFloat(pedido.valor_total);

    // "Crédito": o cliente pagou mais do que o total atual do pedido — sobra que
    // vira saldo de crédito (ocorre quando um pedido já pago é editado para menos).
    let novoStatus = 'Pendente';
    if (totalPago > (valorTotal + 0.01)) {
        novoStatus = 'Crédito';
    } else if (totalPago >= (valorTotal - 0.01)) {
        novoStatus = 'Pago';
    } else if (totalPago > 0) {
        novoStatus = 'Parcial';
    }

    const statusAnterior = pedido.status_pagamento;

    await prisma.$transaction(async (tx) => {
        // Mesmo formato de itens usado nas demais snapshots de pedido — sem
        // isso, o diff de histórico não teria como comparar itens_pedido
        // contra este evento (campo ausente aqui = comparação pulada).
        const atualizado = await tx.pedidos.update({
            where: { id: parseInt(pedido_id) },
            data: { status_pagamento: novoStatus },
            include: { itens_pedido: { include: { produtos: { select: { nome: true } } } } },
        });

        if (novoStatus !== statusAnterior) {
            await logService.registrarAtividade(tx, {
                usuarioId,
                acao: 'atualizacao_automatica',
                entidade: 'pedido',
                entidadeId: atualizado.id,
                snapshot: atualizado,
            });
        }
    });
};

// ============================================================

// Monta o `data` do insert: normaliza datas e prepara os cheques (opcionais,
// criados junto ao pagamento — cada um entra sem data_deposito, ou seja
// "a depositar", salvo se já vier informada).
const montarDadosPagamento = (dadosPagamento) => {
    const { cheques, ...dadosSemCheques } = dadosPagamento;
    const dados = normalizarDatas(dadosSemCheques, ['data_pagamento', 'data_emissao_nota']);

    if (Array.isArray(cheques) && cheques.length > 0) {
        dados.cheques = {
            create: cheques.map((c) => {
                const valor = parseFloat(c.valor);
                if (isNaN(valor) || valor <= 0) {
                    throw new BusinessError('Cada cheque precisa de um valor maior que zero.');
                }
                return normalizarDatas(
                    {
                        numero: c.numero ?? null,
                        banco: c.banco ?? null,
                        agencia: c.agencia ?? null,
                        conta_corrente: c.conta_corrente ?? null,
                        valor,
                        bom_para: c.bom_para ?? null,
                        data_deposito: c.data_deposito ?? null,
                        depositado: c.data_deposito ? true : (c.depositado ?? false),
                    },
                    ['bom_para', 'data_deposito']
                );
            }),
        };
    }

    return dados;
};

// Valida o saldo do pedido e cria o pagamento dentro de uma transação já
// aberta pelo chamador. Relê o pedido a cada chamada, então funciona também em
// laço (cada iteração enxerga os pagamentos inseridos pelas anteriores).
const criarPagamentoTx = async (tx, dadosPagamento, formasPosteriores, usuarioId = null) => {
    const { pedido_id, valor_pago } = dadosPagamento;

    // As checagens abaixo são só de teto (valor > saldo). Sem esta validação,
    // valor negativo passava e reduzia o total recebido do pedido, e valor não
    // numérico virava NaN, escapava de toda comparação e estourava no insert.
    const valorNumerico = parseFloat(valor_pago);
    if (!Number.isFinite(valorNumerico) || valorNumerico <= 0) {
        throw new BusinessError('O valor do pagamento precisa ser maior que zero.');
    }

    const dados = montarDadosPagamento(dadosPagamento);

    const pedido = await tx.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: { pagamentos: true }
    });

    if (!pedido) {
        throw new BusinessError('Pedido não encontrado.', 404);
    }

    if (pedido.ativo === false) {
        throw new BusinessError('Não é possível registrar pagamentos para um pedido desativado ou cancelado.');
    }

    const valorTotal = parseFloat(pedido.valor_total);
    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const ehPosterior = nomesPosteriores.has(dadosPagamento.forma_pagamento);

    if (ehPosterior) {
        // Crediário: verifica contra o total já coberto (real + crediário)
        const totalCoberto = pedido.pagamentos
            .reduce((soma, p) => soma + parseFloat(p.valor_pago), 0);
        const saldoNaoCoberto = valorTotal - totalCoberto;
        if (saldoNaoCoberto <= 0) {
            throw new BusinessError('Este pedido já está totalmente coberto.');
        }
        if (parseFloat(valor_pago) > (saldoNaoCoberto + 0.01)) {
            throw new BusinessError(`Valor excede o saldo disponível. O máximo é R$ ${saldoNaoCoberto.toFixed(2)}.`);
        }
    } else {
        // Pagamento real: verifica apenas contra pagamentos reais anteriores
        const totalPagoReal = pedido.pagamentos
            .filter(p => !nomesPosteriores.has(p.forma_pagamento))
            .reduce((soma, p) => soma + parseFloat(p.valor_pago), 0);
        const saldoDevedorReal = valorTotal - totalPagoReal;
        if (saldoDevedorReal <= 0) {
            throw new BusinessError('Este pedido já está totalmente pago.');
        }
        if (parseFloat(valor_pago) > (saldoDevedorReal + 0.01)) {
            throw new BusinessError(`Valor excede o saldo devedor. O máximo permitido é R$ ${saldoDevedorReal.toFixed(2)}.`);
        }
    }

    const pagamentoCriado = await tx.pagamentos.create({ data: dados });
    await logService.registrarAtividade(tx, {
        usuarioId,
        acao: 'criacao',
        entidade: 'pagamento',
        entidadeId: pagamentoCriado.id,
        snapshot: pagamentoCriado,
    });
    return pagamentoCriado;
};

// Registra os pagamentos de entrada informados (se houver) e cobre o que
// faltar de `valorAlvo` com a primeira forma de crediário cadastrada — tudo
// dentro da MESMA transação do chamador. `valorAlvo` é o valor total do
// pedido (pedido novo, aprovação de orçamento) ou só o aumento de um pedido
// já existente sendo editado (o resto do total já está coberto por
// pagamentos anteriores, que esta função não mexe). Se qualquer pagamento
// falhar a validação, ou faltar forma de crediário para cobrir o restante, a
// transação inteira desfaz — o registro (pedido, orçamento aprovado, edição)
// não chega a existir, em vez de ficar com cobertura incompleta e sem
// nenhum aviso. Único lugar que sabe fazer "cobrir um valor com entrada +
// crediário automático" — reusado por criarPedidoTx (POST /pedidos),
// atualizarPedido (aumento no PUT /pedidos/:id) e aprovarOrcamento.
const cobrirValorTx = async (tx, { pedidoId, valorAlvo }, pagamentosEntrada, formasPosteriores, usuarioId = null) => {
    const alvo = parseFloat(valorAlvo);
    let totalCoberto = 0;
    for (const pagamento of pagamentosEntrada) {
        const criado = await criarPagamentoTx(
            tx,
            { ...pagamento, pedido_id: pedidoId },
            formasPosteriores,
            usuarioId
        );
        totalCoberto += parseFloat(criado.valor_pago);
    }

    const restante = alvo - totalCoberto;
    if (restante <= 0.005) return;

    // Só uma forma ATIVA pode ser escolhida pra lançar um crediário NOVO —
    // `formasPosteriores` inclui formas desativadas de propósito (usado em
    // outros lugares pra classificar pagamentos antigos), mas usar uma
    // desativada aqui criaria um pagamento novo apontando pra uma forma que
    // não deveria mais estar em uso (mesmo comportamento que o front antigo
    // já tinha, via FormaPagamentoService.listar() filtrando ativo).
    const crediario = formasPosteriores.find((f) => f.ativo !== false);
    if (!crediario) {
        throw new BusinessError(
            'Nenhuma forma de crediário cadastrada — cadastre uma para poder finalizar sem cobrir o valor total.'
        );
    }

    await criarPagamentoTx(
        tx,
        {
            pedido_id: pedidoId,
            valor_pago: restante,
            forma_pagamento: crediario.nome,
            data_pagamento: new Date().toISOString(),
        },
        formasPosteriores,
        usuarioId
    );
};

const criarPagamento = async (dadosPagamento, usuarioId = null) => {
    const formasPosteriores = await formaPagamentoService.listarPosteriores();

    const novoPagamento = await prisma.$transaction(
        (tx) => criarPagamentoTx(tx, dadosPagamento, formasPosteriores, usuarioId)
    );

    await recalcularStatusPedido(dadosPagamento.pedido_id, usuarioId);

    return novoPagamento.id;
};

// Registra os pagamentos reais de um pedido e abate o crediário existente na
// MESMA transação: o valor recebido reduz o "a receber" do cliente. Antes isso
// era orquestrado pelo app em várias chamadas soltas (apagar todos os
// crediários, depois recriar o saldo), e qualquer falha no meio — rede, erro do
// servidor, app fechado — apagava o crediário do cliente sem deixar rastro.
const registrarPagamentosDoPedido = async (pedidoId, pagamentos, usuarioId = null) => {
    const id = parseInt(pedidoId);
    const formasPosteriores = await formaPagamentoService.listarPosteriores();
    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));

    await prisma.$transaction(async (tx) => {
        const pedido = await tx.pedidos.findUnique({
            where: { id },
            include: { pagamentos: true },
        });

        if (!pedido) {
            throw new BusinessError('Pedido não encontrado.', 404);
        }
        if (pedido.ativo === false) {
            throw new BusinessError('Não é possível registrar pagamentos para um pedido desativado ou cancelado.');
        }

        // Crediários existentes ANTES desta chamada — capturados aqui para não
        // confundir com qualquer coisa criada no laço abaixo.
        const crediarios = pedido.pagamentos
            .filter((p) => nomesPosteriores.has(p.forma_pagamento));

        let totalRealPago = 0;
        for (const pagamento of pagamentos) {
            const criado = await criarPagamentoTx(
                tx,
                { ...pagamento, pedido_id: id },
                formasPosteriores,
                usuarioId
            );
            if (!nomesPosteriores.has(criado.forma_pagamento)) {
                totalRealPago += parseFloat(criado.valor_pago);
            }
        }

        if (crediarios.length === 0 || totalRealPago <= 0.005) return;

        const totalCredito = crediarios
            .reduce((soma, p) => soma + parseFloat(p.valor_pago), 0);

        await tx.pagamentos.deleteMany({
            where: { id: { in: crediarios.map((c) => c.id) } },
        });

        const novoSaldoCredito = totalCredito - totalRealPago;
        if (novoSaldoCredito > 0.005) {
            const novoPagamento = await tx.pagamentos.create({
                data: {
                    pedido_id: id,
                    valor_pago: novoSaldoCredito,
                    forma_pagamento: crediarios[0].forma_pagamento,
                    data_pagamento: new Date(),
                },
            });
            await logService.registrarAtividade(tx, {
                usuarioId,
                acao: 'atualizacao',
                entidade: 'pagamento',
                entidadeId: novoPagamento.id,
                snapshot: novoPagamento,
            });
        }
    });

    await recalcularStatusPedido(id, usuarioId);
};

// Listagem geral de pagamentos. Aceita intervalo de datas e tem teto de
// resultados — antes devolvia a tabela inteira com joins a cada chamada.
const LIMITE_PADRAO_PAGAMENTOS = 200;
const LIMITE_MAXIMO_PAGAMENTOS = 1000;

const listarPagamentos = async ({ de, ate, limite } = {}) => {
    const take = Math.min(
        Number.parseInt(limite, 10) || LIMITE_PADRAO_PAGAMENTOS,
        LIMITE_MAXIMO_PAGAMENTOS
    );

    const intervalo = (de || ate) ? {
        criado_em: {
            ...(de && { gte: new Date(de) }),
            ...(ate && { lte: new Date(ate) }),
        }
    } : {};

    return await prisma.pagamentos.findMany({
        take,
        orderBy: { criado_em: 'desc' },
        where: {
            ...intervalo,
            pedidos: { ativo: true }
        },
        include: {
            pedidos: {
                select: {
                    id: true,
                    status_geral: true,
                    valor_total: true
                }
            }
        }
    });
};

// Lista pagamentos reais que ainda não foram colocados em uma conta (conta pendente).
// Ex: pagamentos em dinheiro que entram no PDV sem conta definida.
// Exclui crediário/posterior (são "a receber", não dinheiro sem conta), também
// cheque/depósito-posterior (a conta do cheque é definida no depósito, não aqui)
// e escambo/troca (não é dinheiro — não tem conta).
const listarPagamentosPendentesDeConta = async () => {
    const [formasPosteriores, formasDeposito, formasEscambo] = await Promise.all([
        formaPagamentoService.listarPosteriores(),
        formaPagamentoService.listarDepositoPosterior(),
        formaPagamentoService.listarEscambo(),
    ]);
    const nomesExcluidos = [...formasPosteriores, ...formasDeposito, ...formasEscambo].map(f => f.nome);

    const where = {
        OR: [{ conta: null }, { conta: '' }],
        pedidos: { ativo: true },
    };
    if (nomesExcluidos.length > 0) {
        where.forma_pagamento = { notIn: nomesExcluidos };
    }

    return await prisma.pagamentos.findMany({
        where,
        select: {
            id: true,
            valor_pago: true,
            forma_pagamento: true,
            conta: true,
            data_pagamento: true,
            criado_em: true,
            nome_pagador: true,
            pedidos: {
                select: {
                    id: true,
                    temporada_ano: true,
                    numero_temporada: true,
                    clientes: { select: { id: true, nome: true } }
                }
            }
        },
        orderBy: { criado_em: 'desc' }
    });
};

// Campos editáveis de um pagamento já existente. `pedido_id` fica de fora de
// propósito: trocar o pedido de um pagamento só recalculava o status do pedido
// NOVO, deixando o antigo marcado como pago sem ter o dinheiro. Cheques são
// gerenciados pelos endpoints de /api/cheques, não por aqui.
const CAMPOS_PAGAMENTO_EDITAVEIS = [
    'valor_pago',
    'forma_pagamento',
    'data_pagamento',
    'conta',
    'parcelas',
    'nome_pagador',
    'cpf_cnpj_pagador',
    'escambo_quantidade',
    'status_nota',
    'numero_nota',
    'data_emissao_nota',
];

const atualizarPagamento = async (id, dados, usuarioId = null) => {
    const camposPermitidos = Object.fromEntries(
        Object.entries(dados).filter(([chave]) => CAMPOS_PAGAMENTO_EDITAVEIS.includes(chave))
    );
    const dadosNormalizados = normalizarDatas(camposPermitidos, ['data_pagamento', 'data_emissao_nota']);

    if (dadosNormalizados.valor_pago !== undefined) {
        const valorNumerico = parseFloat(dadosNormalizados.valor_pago);
        if (!Number.isFinite(valorNumerico) || valorNumerico <= 0) {
            throw new BusinessError('O valor do pagamento precisa ser maior que zero.');
        }
    }

    const pagamentoAtualizado = await prisma.$transaction(async (tx) => {
        const pagamentoAtual = await tx.pagamentos.findUnique({
            where: { id: parseInt(id) },
            include: {
                pedidos: {
                    include: { pagamentos: true }
                }
            }
        });

        if (!pagamentoAtual) {
            throw new BusinessError('Pagamento não encontrado.', 404);
        }

        if (dados.valor_pago !== undefined) {
            const pedido = pagamentoAtual.pedidos;
            const novoValorPago = parseFloat(dados.valor_pago);

            const totalPagoOutros = pedido.pagamentos.reduce((soma, p) => {
                if (p.id === parseInt(id)) return soma;
                return soma + parseFloat(p.valor_pago);
            }, 0);

            const saldoPermitido = parseFloat(pedido.valor_total) - totalPagoOutros;

            if (novoValorPago > (saldoPermitido + 0.01)) {
                throw new BusinessError(`Valor excede o saldo devedor. O máximo permitido para esta edição é R$ ${saldoPermitido.toFixed(2)}.`);
            }
        }

        const atualizado = await tx.pagamentos.update({
            where: { id: parseInt(id) },
            data: dadosNormalizados,
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao',
            entidade: 'pagamento',
            entidadeId: atualizado.id,
            snapshot: atualizado,
        });
        return atualizado;
    });

    await recalcularStatusPedido(pagamentoAtualizado.pedido_id, usuarioId);

    return pagamentoAtualizado;
};

const eliminarPagamento = async (id, usuarioId = null) => {
    const pagamento = await prisma.pagamentos.findUnique({
        where: { id: parseInt(id) }
    });

    if (!pagamento) {
        throw new BusinessError('Pagamento não encontrado.', 404);
    }

    const resultado = await prisma.$transaction(async (tx) => {
        const excluido = await tx.pagamentos.delete({
            where: { id: parseInt(id) }
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'exclusao',
            entidade: 'pagamento',
            entidadeId: excluido.id,
            snapshot: excluido,
        });
        return excluido;
    });

    await recalcularStatusPedido(pagamento.pedido_id, usuarioId);

    return resultado;
};

module.exports = {
    criarPagamento,
    registrarPagamentosDoPedido,
    cobrirValorTx,
    listarPagamentos,
    listarPagamentosPendentesDeConta,
    atualizarPagamento,
    eliminarPagamento,
    recalcularStatusPedido
};
