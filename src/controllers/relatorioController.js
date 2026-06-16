const relatorioService = require('../services/relatorioService');

const relatorioPagamentos = async (req, res, next) => {
    try {
        const { de, ate, forma } = req.query;
        const dados = await relatorioService.relatorioPagamentos({ de, ate, forma });
        res.status(200).json(dados);
    } catch (erro) {
        next(erro);
    }
};

const relatorioPDF = async (req, res, next) => {
    try {
        const { de, ate, forma } = req.query;
        const buffer = await relatorioService.gerarRelatorioPDF({ de, ate, forma });
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', 'attachment; filename="relatorio_pagamentos.pdf"');
        res.status(200).send(buffer);
    } catch (erro) {
        next(erro);
    }
};

const relatorioPedidos = async (req, res, next) => {
    try {
        const { de, ate, statusPagamento, statusEntrega, clienteId } = req.query;
        const dados = await relatorioService.relatorioPedidos({ de, ate, statusPagamento, statusEntrega, clienteId });
        res.status(200).json(dados);
    } catch (erro) {
        next(erro);
    }
};

const relatorioPedidosPDF = async (req, res, next) => {
    try {
        const { de, ate, statusPagamento, statusEntrega, clienteId } = req.query;
        const buffer = await relatorioService.gerarRelatorioPedidosPDF({ de, ate, statusPagamento, statusEntrega, clienteId });
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', 'attachment; filename="relatorio_pedidos.pdf"');
        res.status(200).send(buffer);
    } catch (erro) {
        next(erro);
    }
};

module.exports = { relatorioPagamentos, relatorioPDF, relatorioPedidos, relatorioPedidosPDF };
