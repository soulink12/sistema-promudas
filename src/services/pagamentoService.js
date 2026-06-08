const prisma = require('../config/database');

// Recalcula o status de pagamento do pedido com base na soma real dos pagamentos no banco
const recalcularStatusPedido = async (pedido_id) => {
    const pedido = await prisma.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: { pagamentos: true }
    });

    if (!pedido) return;

    const totalPago = pedido.pagamentos.reduce((soma, p) => soma + parseFloat(p.valor_pago), 0);
    const valorTotal = parseFloat(pedido.valor_total);

    let novoStatus = 'Pendente';

    if (totalPago >= (valorTotal - 0.01)) {
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

    const pedido = await prisma.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: { pagamentos: true }
    });

    if (!pedido) {
        throw new Error('Pedido não encontrado.');
    }

    if (pedido.ativo === false) {
        throw new Error('Não é possível registrar pagamentos para um pedido desativado ou cancelado.');
    }

    const totalPagoAnterior = pedido.pagamentos.reduce((soma, p) => soma + parseFloat(p.valor_pago), 0);
    const valorTotal = parseFloat(pedido.valor_total);
    const saldoDevedor = valorTotal - totalPagoAnterior;

    if (saldoDevedor <= 0) {
        throw new Error('Este pedido já está totalmente pago.');
    }

    if (parseFloat(valor_pago) > (saldoDevedor + 0.01)) {
        throw new Error(`Valor excede o saldo devedor. O máximo permitido é R$ ${saldoDevedor.toFixed(2)}.`);
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
        throw new Error('Pagamento não encontrado.');
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
            throw new Error(`Valor excede o saldo devedor. O máximo permitido para esta edição é R$ ${saldoPermitido.toFixed(2)}.`);
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
        throw new Error('Pagamento não encontrado.');
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
    eliminarPagamento
};
