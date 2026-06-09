const pagamentoService = require('../services/pagamentoService');

const criarPagamento = async (req, res) => {
    try {
        const id = await pagamentoService.criarPagamento(req.body);
        res.status(201).json({ mensagem: 'Pagamento criado com sucesso', id });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao criar pagamento' });
    }
};

const listarPagamentos = async (req, res) => {
    try {
        const pagamentos = await pagamentoService.listarPagamentos();
        res.status(200).json(pagamentos);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar pagamentos' });
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
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao atualizar pagamento' });
    }
};

const eliminarPagamento = async (req, res) => {
    try {
        const { id } = req.params;
        await pagamentoService.eliminarPagamento(id);
        res.status(200).json({ mensagem: 'Pagamento apagado com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao apagar pagamento' });
    }
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    atualizarPagamento,
    eliminarPagamento
};