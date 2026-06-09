const relatorioService = require('../services/relatorioService');

const relatorioPagamentos = async (req, res) => {
    try {
        const { de, ate, forma } = req.query;
        const dados = await relatorioService.relatorioPagamentos({ de, ate, forma });
        res.status(200).json(dados);
    } catch (erro) {
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao gerar relatório.' });
    }
};

const relatorioPDF = async (req, res) => {
    try {
        const { de, ate, forma } = req.query;
        const buffer = await relatorioService.gerarRelatorioPDF({ de, ate, forma });
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', 'attachment; filename="relatorio_pagamentos.pdf"');
        res.status(200).send(buffer);
    } catch (erro) {
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao gerar PDF.' });
    }
};

const relatorioPedidos = async (req, res) => {
    try {
        const { de, ate, statusPagamento, statusRetirada, clienteId } = req.query;
        const dados = await relatorioService.relatorioPedidos({ de, ate, statusPagamento, statusRetirada, clienteId });
        res.status(200).json(dados);
    } catch (erro) {
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao gerar relatório.' });
    }
};

module.exports = { relatorioPagamentos, relatorioPDF, relatorioPedidos };
