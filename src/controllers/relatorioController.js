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

module.exports = { relatorioPagamentos };
