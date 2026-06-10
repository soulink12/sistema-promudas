const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');

// Recalcula o status de pagamento do pedido com base na soma real dos pagamentos no banco.
// Pagamentos com forma de pagamento posterior (ex: crediário) não contam como valor recebido.
const recalcularStatusPedido = async (pedido_id) => {
    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(pedido_id) },
            include: { pagamentos: true }
        }),
        prisma.formas_pagamento.findMany({
            where: { pagamento_posterior: true },
            select: { nome: true }
        })
    ]);

    if (!pedido) return;

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));

    // Só conta pagamentos efetivamente recebidos (exclui crediário e similares)
    const totalPago = pedido.pagamentos
        .filter(p => !nomesPosteriores.has(p.forma_pagamento))
        .reduce((soma, p) => soma + parseFloat(p.valor_pago), 0);

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
        prisma.formas_pagamento.findMany({
            where: { pagamento_posterior: true },
            select: { nome: true }
        })
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

    const novoPagamento = await prisma.pagamentos.create({
        data: dadosPagamento
    });

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

    const pagamentoAtualizado = await prisma.pagamentos.update({
        where: { id: parseInt(id) },
        data: dados,
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
    atualizarPagamento,
    eliminarPagamento,
    recalcularStatusPedido
};
