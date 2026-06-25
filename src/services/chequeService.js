const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { normalizarDatas } = require('../utils/parseData');
const { recalcularStatusPedido } = require('./pagamentoService');

// Cheques ainda não depositados (data_deposito null), de pedidos ativos.
// Alimenta a notificação "cheques a depositar".
const listarChequesADepositar = async () => {
    return await prisma.cheques.findMany({
        where: {
            data_deposito: null,
            pagamentos: { pedidos: { ativo: true } },
        },
        include: {
            pagamentos: {
                select: {
                    id: true,
                    forma_pagamento: true,
                    pedidos: {
                        select: {
                            id: true,
                            temporada_ano: true,
                            numero_temporada: true,
                            clientes: { select: { id: true, nome: true } },
                        },
                    },
                },
            },
        },
        orderBy: [{ bom_para: 'asc' }, { criado_em: 'asc' }],
    });
};

// Atualiza um cheque. Usado tanto para corrigir dados (número/banco/agência/conta)
// quanto para registrar o depósito (informando data_deposito → marca depositado).
const atualizarCheque = async (id, dados) => {
    const cheque = await prisma.cheques.findUnique({ where: { id: parseInt(id) } });
    if (!cheque) throw new BusinessError('Cheque não encontrado.', 404);

    if (dados.valor !== undefined) {
        const valor = parseFloat(dados.valor);
        if (isNaN(valor) || valor <= 0) {
            throw new BusinessError('O valor do cheque deve ser maior que zero.');
        }
    }

    // `conta` é a conta de destino — vive no pagamento pai, não no cheque. Ao
    // depositar, define a conta do pagamento (tira-o da lista "sem conta").
    const { conta, ...dadosCheque } = dados;
    const dadosNormalizados = normalizarDatas(dadosCheque, ['bom_para', 'data_deposito']);

    // Depositado segue a presença de data_deposito (informar data = depositar;
    // limpar a data = voltar a "a depositar").
    if ('data_deposito' in dadosNormalizados) {
        dadosNormalizados.depositado = !!dadosNormalizados.data_deposito;
    }

    const atualizado = await prisma.cheques.update({
        where: { id: parseInt(id) },
        data: dadosNormalizados,
    });

    if (conta !== undefined) {
        await prisma.pagamentos.update({
            where: { id: cheque.pagamento_id },
            data: { conta },
        });
    }

    // Depositar/desfazer um cheque muda o valor recebido do pedido → recalcula
    // o status de pagamento (cheque só conta como recebido depois de depositado).
    const pagamento = await prisma.pagamentos.findUnique({
        where: { id: cheque.pagamento_id },
        select: { pedido_id: true },
    });
    if (pagamento?.pedido_id) await recalcularStatusPedido(pagamento.pedido_id);

    return atualizado;
};

module.exports = { listarChequesADepositar, atualizarCheque };
