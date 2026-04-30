const pagamentoService = require('../services/pagamentoService');

const criarPagamento = async (req, res) => {
    try {
        const id = await pagamentoService.criarPagamento(req.body);
        res.status(201).json({ mensagem: 'Pagamento criado com sucesso', id });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao criar pagamento', detalhe: erro.message });
    }
};

const listarPagamentos = async (req, res) => {
    try {
        const pagamentos = await pagamentoService.listarPagamentos();
        res.status(200).json(pagamentos);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar pagamentos', detalhe: erro.message });
    }
};

const atualizarPagamento = async (req, res) => {
    try {
        const { id } = req.params;
        const dados = req.body;
        await pagamentoService.atualizarPagamento(id, dados);
        res.status(200).json({ mensagem: 'Pagamento atualizado com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao atualizar pagamento', detalhe: erro.message });
    }
};

const eliminarPagamento = async (req, res) => {
    try {
        const { id } = req.params;
        await pagamentoService.eliminarPagamento(id);
        res.status(200).json({ mensagem: 'Pagamento apagado com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao apagar pagamento', detalhe: erro.message });
    }
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    atualizarPagamento,
    eliminarPagamento
};