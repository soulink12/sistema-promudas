const prisma = require('../config/database');

const criarPagamento = async (dadosPagamento) => {
    const { encomenda_id, valor_pago } = dadosPagamento;

    // 1. Busca a encomenda com seus pagamentos e o status 'ativo'
    const encomenda = await prisma.encomendas.findUnique({
        where: { id: parseInt(encomenda_id) },
        include: { pagamentos: true }
    });

    if (!encomenda) {
        throw new Error('Encomenda não encontrada.');
    }

    // 2. NOVA VALIDAÇÃO: Bloqueia pagamento se a encomenda estiver inativa (ativo: false)
    if (encomenda.ativo === false) {
        throw new Error('Não é possível registar pagamentos para uma encomenda desativada ou cancelada.');
    }

    // 3. Calcula o saldo devedor (apenas desta encomenda)
    const totalPagoAnterior = encomenda.pagamentos.reduce((soma, p) => {
        return soma + parseFloat(p.valor_pago);
    }, 0);

    const valorTotalEncomenda = parseFloat(encomenda.valor_total);
    const saldoDevedor = valorTotalEncomenda - totalPagoAnterior;

    // 4. Validação de saldo
    if (saldoDevedor <= 0) {
        throw new Error('Esta encomenda já está totalmente paga.');
    }

    if (parseFloat(valor_pago) > (saldoDevedor + 0.01)) {
        throw new Error(`Valor excede o saldo devedor. O máximo permitido é R$ ${saldoDevedor.toFixed(2)}.`);
    }

    // 5. Cria o pagamento
    const novoPagamento = await prisma.pagamentos.create({
        data: dadosPagamento
    });

    // 6. Atualiza status se quitado
    if (parseFloat(valor_pago) >= (saldoDevedor - 0.01)) {
        await prisma.encomendas.update({
            where: { id: parseInt(encomenda_id) },
            data: { status_pagamento: 'Pago' }
        });
    }

    return novoPagamento.id;
};

const listarPagamentos = async () => {
    // Como não tem campo "ativo", listamos todos (ou podemos filtrar por encomenda no futuro)
    const pagamentos = await prisma.pagamentos.findMany({
        include: {
            encomendas: true // Traz os dados da encomenda vinculada (opcional, mas muito útil)
        }
    });
    return pagamentos;
};

const atualizarPagamento = async (id, dados) => {
    return await prisma.pagamentos.update({
        where: { id: parseInt(id) },
        data: dados,
    });
};

const eliminarPagamento = async (id) => {
    // Como não existe o campo "ativo", fazemos a exclusão real do registo
    return await prisma.pagamentos.delete({
        where: { id: parseInt(id) }
    });
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    atualizarPagamento,
    eliminarPagamento
};