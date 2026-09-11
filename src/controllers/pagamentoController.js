const pagamentoService = require('../services/pagamentoService');
const pedidoService = require('../services/pedidoService');

const criarPagamento = async (req, res, next) => {
    try {
        const { pedido_id, valor_pago, forma_pagamento } = req.body ?? {};

        if (!pedido_id || valor_pago === undefined || !forma_pagamento) {
            return res.status(400).json({
                erro: 'Informe o pedido, o valor pago e a forma de pagamento.'
            });
        }

        const id = await pagamentoService.criarPagamento(req.body, req.usuarioId);
        pedidoService.notificarPedido(pedido_id, 'pedidoPagamento')
            .catch((erro) => console.error('Falha ao notificar pagamento do pedido:', erro));
        res.status(201).json({ mensagem: 'Pagamento criado com sucesso', id });
    } catch (erro) {
        next(erro);
    }
};

const listarPagamentos = async (req, res, next) => {
    try {
        const { de, ate, limite } = req.query;
        const pagamentos = await pagamentoService.listarPagamentos({ de, ate, limite });
        res.status(200).json(pagamentos);
    } catch (erro) {
        next(erro);
    }
};

const listarPagamentosPendentesDeConta = async (req, res, next) => {
    try {
        const pagamentos = await pagamentoService.listarPagamentosPendentesDeConta();
        res.status(200).json(pagamentos);
    } catch (erro) {
        next(erro);
    }
};

const atualizarPagamento = async (req, res, next) => {
    try {
        const { id } = req.params;
        const dados = req.body;
        await pagamentoService.atualizarPagamento(id, dados, req.usuarioId);
        res.status(200).json({ mensagem: 'Pagamento atualizado com sucesso' });
    } catch (erro) {
        next(erro);
    }
};

const eliminarPagamento = async (req, res, next) => {
    try {
        const { id } = req.params;
        await pagamentoService.eliminarPagamento(id, req.usuarioId);
        res.status(200).json({ mensagem: 'Pagamento apagado com sucesso' });
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    listarPagamentosPendentesDeConta,
    atualizarPagamento,
    eliminarPagamento
};
