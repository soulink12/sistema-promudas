const formaPagamentoService = require('../services/formaPagamentoService');

const listarFormasPagamento = async (req, res, next) => {
    try {
        const formas = await formaPagamentoService.listarFormasPagamento();
        res.status(200).json(formas);
    } catch (erro) {
        next(erro);
    }
};

const criarForma = async (req, res, next) => {
    try {
        const { nome, pagamento_posterior, conta_posterior, deposito_posterior, parcelado_em_ate } = req.body;
        if (!nome || nome.trim() === '') {
            return res.status(400).json({ erro: 'O campo nome é obrigatório.' });
        }
        const nova = await formaPagamentoService.criarForma(nome.trim(), pagamento_posterior ?? false, conta_posterior ?? false, parcelado_em_ate ?? 1, deposito_posterior ?? false);
        res.status(201).json(nova);
    } catch (erro) {
        next(erro);
    }
};

const atualizarForma = async (req, res, next) => {
    try {
        const id = parseInt(req.params.id);
        const { nome, pagamento_posterior, conta_posterior, deposito_posterior, ativo, parcelado_em_ate } = req.body;
        const dados = {};
        if (nome !== undefined) dados.nome = nome.trim();
        if (pagamento_posterior !== undefined) dados.pagamento_posterior = pagamento_posterior;
        if (conta_posterior !== undefined) dados.conta_posterior = conta_posterior;
        if (deposito_posterior !== undefined) dados.deposito_posterior = deposito_posterior;
        if (ativo !== undefined) dados.ativo = ativo;
        if (parcelado_em_ate !== undefined) dados.parcelado_em_ate = parcelado_em_ate;
        const atualizada = await formaPagamentoService.atualizarForma(id, dados);
        res.status(200).json(atualizada);
    } catch (erro) {
        next(erro);
    }
};

const deletarForma = async (req, res, next) => {
    try {
        const id = parseInt(req.params.id);
        await formaPagamentoService.deletarForma(id);
        res.status(204).send();
    } catch (erro) {
        next(erro);
    }
};

module.exports = { listarFormasPagamento, criarForma, atualizarForma, deletarForma };
