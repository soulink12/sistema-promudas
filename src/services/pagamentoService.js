const prisma = require('../config/database');

/**
 * FUNÇÃO DE AUTOMAÇÃO (INTERNA)
 * Recalcula o status de pagamento da encomenda com base na soma real dos pagamentos no banco.
 * Isso garante que o status nunca fique "mentiroso" se um pagamento for editado ou apagado.
 */
const recalcularStatusEncomenda = async (encomenda_id) => {
    // 1. Busca a encomenda e TODOS os pagamentos vinculados a ela
    const encomenda = await prisma.encomendas.findUnique({
        where: { id: parseInt(encomenda_id) },
        include: { pagamentos: true }
    });

    if (!encomenda) return;

    // 2. Soma o valor total de todos os pagamentos existentes
    const totalPago = encomenda.pagamentos.reduce((soma, p) => {
        return soma + parseFloat(p.valor_pago);
    }, 0);

    const valorTotalEncomenda = parseFloat(encomenda.valor_total);

    // 3. Define o status logicamente
    let novoStatus = 'Pendente';
    
    // Usamos uma margem de 0.01 para evitar erros de arredondamento de centavos
    if (totalPago >= (valorTotalEncomenda - 0.01)) {
        novoStatus = 'Pago';
    } else if (totalPago > 0) {
        novoStatus = 'Parcial';
    }

    // 4. Sincroniza o novo status com a tabela de encomendas
    await prisma.encomendas.update({
        where: { id: parseInt(encomenda_id) },
        data: { status_pagamento: novoStatus }
    });
};

// ============================================================
// SERVIÇOS DE PAGAMENTO
// ============================================

const criarPagamento = async (dadosPagamento) => {
    const { encomenda_id, valor_pago } = dadosPagamento;

    const encomenda = await prisma.encomendas.findUnique({
        where: { id: parseInt(encomenda_id) },
        include: { pagamentos: true }
    });

    if (!encomenda) {
        throw new Error('Encomenda não encontrada.');
    }

    if (encomenda.ativo === false) {
        throw new Error('Não é possível registar pagamentos para uma encomenda desativada ou cancelada.');
    }

    const totalPagoAnterior = encomenda.pagamentos.reduce((soma, p) => {
        return soma + parseFloat(p.valor_pago);
    }, 0);

    const valorTotalEncomenda = parseFloat(encomenda.valor_total);
    const saldoDevedor = valorTotalEncomenda - totalPagoAnterior;

    if (saldoDevedor <= 0) {
        throw new Error('Esta encomenda já está totalmente paga.');
    }

    if (parseFloat(valor_pago) > (saldoDevedor + 0.01)) {
        throw new Error(`Valor excede o saldo devedor. O máximo permitido é R$ ${saldoDevedor.toFixed(2)}.`);
    }

    const novoPagamento = await prisma.pagamentos.create({
        data: dadosPagamento
    });

    // AUTOMAÇÃO: Dispara o recálculo após criar
    await recalcularStatusEncomenda(encomenda_id);

    return novoPagamento.id;
};

const listarPagamentos = async () => {
    const pagamentos = await prisma.pagamentos.findMany({
        where: {
            encomendas: { ativo: true }
        },
        include: {
            encomendas: {
                select: {
                    id: true,
                    status_geral: true,
                    valor_total: true
                }
            }
        }
    });
    return pagamentos;
};

const atualizarPagamento = async (id, dados) => {
    // 1. Busca o pagamento atual junto com os dados da encomenda e todos os pagamentos dela
    const pagamentoAtual = await prisma.pagamentos.findUnique({
        where: { id: parseInt(id) },
        include: {
            encomendas: {
                include: { pagamentos: true }
            }
        }
    });

    if (!pagamentoAtual) {
        throw new Error('Pagamento não encontrado.');
    }

    // 2. Se o utilizador enviou um novo "valor_pago", fazemos a validação de segurança
    if (dados.valor_pago !== undefined) {
        const encomenda = pagamentoAtual.encomendas;
        const novoValorPago = parseFloat(dados.valor_pago);

        // Soma os OUTROS pagamentos da mesma encomenda (ignorando o valor antigo deste pagamento que estamos editando)
        const totalPagoOutros = encomenda.pagamentos.reduce((soma, p) => {
            if (p.id === parseInt(id)) {
                return soma; // Pula o pagamento atual
            }
            return soma + parseFloat(p.valor_pago);
        }, 0);

        const valorTotalEncomenda = parseFloat(encomenda.valor_total);
        
        // O máximo que este pagamento pode ter é o Valor Total da Encomenda menos o que já foi pago nos OUTROS recibos
        const saldoPermitido = valorTotalEncomenda - totalPagoOutros;

        if (novoValorPago > (saldoPermitido + 0.01)) {
            throw new Error(`Valor excede o saldo devedor. O máximo permitido para esta edição é R$ ${saldoPermitido.toFixed(2)}.`);
        }
    }

    // 3. Passou na validação (ou não editou o valor), então atualiza no banco
    const pagamentoAtualizado = await prisma.pagamentos.update({
        where: { id: parseInt(id) },
        data: dados,
    });

    // 4. AUTOMAÇÃO: Dispara o recálculo pois o valor mudou com sucesso
    await recalcularStatusEncomenda(pagamentoAtualizado.encomenda_id);

    return pagamentoAtualizado;
};

const eliminarPagamento = async (id) => {
    // 1. Localiza o pagamento antes de apagar para saber qual encomenda recalcular
    const pagamento = await prisma.pagamentos.findUnique({
        where: { id: parseInt(id) }
    });

    if (!pagamento) {
        throw new Error('Pagamento não encontrado.');
    }

    // 2. Apaga o registro
    const resultado = await prisma.pagamentos.delete({
        where: { id: parseInt(id) }
    });

    // 3. AUTOMAÇÃO: Recalcula. Se era o único pagamento, a encomenda voltará para "Pendente"
    await recalcularStatusEncomenda(pagamento.encomenda_id);

    return resultado;
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    atualizarPagamento,
    eliminarPagamento
};