const formaPagamentoService = require('../services/formaPagamentoService');

const listarFormasPagamento = async (req, res) => {
    try {
        const formas = await formaPagamentoService.listarFormasPagamento();
        res.status(200).json(formas);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar formas de pagamento', detalhe: erro.message });
    }
};

module.exports = { listarFormasPagamento };
