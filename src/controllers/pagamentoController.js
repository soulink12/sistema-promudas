const pagamentoService = require('../services/pagamentoService');

const criarPagamento = async (req, res, next) => {
    try {
        const id = await pagamentoService.criarPagamento(req.body);
        res.status(201).json({ mensagem: 'Pagamento criado com sucesso', id });
    } catch (erro) {
        next(erro);
    }
};

const listarPagamentos = async (req, res, next) => {
    try {
        const pagamentos = await pagamentoService.listarPagamentos();
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
        await pagamentoService.atualizarPagamento(id, dados);
        res.status(200).json({ mensagem: 'Pagamento atualizado com sucesso' });
    } catch (erro) {
        next(erro);
    }
};

const eliminarPagamento = async (req, res, next) => {
    try {
        const { id } = req.params;
        await pagamentoService.eliminarPagamento(id);
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
