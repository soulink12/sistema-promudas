const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { normalizarDatas } = require('../utils/parseData');
const formaPagamentoService = require('./formaPagamentoService');

// Recalcula o status de pagamento do pedido com base na soma real dos pagamentos no banco.
// Pagamentos com forma de pagamento posterior (ex: crediário) não contam como valor recebido.
const recalcularStatusPedido = async (pedido_id) => {
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

    await prisma.pedidos.update({
        where: { id: parseInt(pedido_id) },
        data: { status_pagamento: novoStatus }
    });
};

// ============================================================

const criarPagamento = async (dadosPagamento) => {
    const { pedido_id, valor_pago } = dadosPagamento;

    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(pedido_id) },
            include: { pagamentos: true }
        }),
        formaPagamentoService.listarPosteriores()
    ]);

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

    // Cheques (opcionais) são criados junto ao pagamento. Cada cheque entra sem
    // data_deposito (= "a depositar") salvo se já vier informada.
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

    const novoPagamento = await prisma.pagamentos.create({ data: dados });

    await recalcularStatusPedido(pedido_id);

    return novoPagamento.id;
};

const listarPagamentos = async () => {
    return await prisma.pagamentos.findMany({
        where: {
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
// Exclui crediário/posterior (são "a receber", não dinheiro sem conta) e também
// cheque/depósito-posterior (a conta do cheque é definida no depósito, não aqui).
const listarPagamentosPendentesDeConta = async () => {
    const [formasPosteriores, formasDeposito] = await Promise.all([
        formaPagamentoService.listarPosteriores(),
        formaPagamentoService.listarDepositoPosterior(),
    ]);
    const nomesExcluidos = [...formasPosteriores, ...formasDeposito].map(f => f.nome);

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

const atualizarPagamento = async (id, dados) => {
    const pagamentoAtual = await prisma.pagamentos.findUnique({
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

    // Cheques são gerenciados pelos endpoints de /api/cheques, não por aqui.
    const { cheques: _ignorado, ...dadosSemCheques } = dados;
    const pagamentoAtualizado = await prisma.pagamentos.update({
        where: { id: parseInt(id) },
        data: normalizarDatas(dadosSemCheques, ['data_pagamento', 'data_emissao_nota']),
    });

    await recalcularStatusPedido(pagamentoAtualizado.pedido_id);

    return pagamentoAtualizado;
};

const eliminarPagamento = async (id) => {
    const pagamento = await prisma.pagamentos.findUnique({
        where: { id: parseInt(id) }
    });

    if (!pagamento) {
        throw new BusinessError('Pagamento não encontrado.', 404);
    }

    const resultado = await prisma.pagamentos.delete({
        where: { id: parseInt(id) }
    });

    await recalcularStatusPedido(pagamento.pedido_id);

    return resultado;
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    listarPagamentosPendentesDeConta,
    atualizarPagamento,
    eliminarPagamento,
    recalcularStatusPedido
};
