const produtoService = require('../services/produtoService');

const criarProduto = async (req, res, next) => {
    try {
        const dados = req.body;

        if (!dados.nome || dados.preco === undefined) {
            return res.status(400).json({ erro: 'Nome e preço do produto são obrigatórios.' });
        }

        const novoId = await produtoService.criarProduto(dados);
        return res.status(201).json({ mensagem: 'Produto cadastrado com sucesso!', id: novoId });

    } catch (erro) {
        next(erro);
    }
};

const listarProdutos = async (req, res, next) => {
    try {
        const produtos = await produtoService.listarProdutos();
        return res.status(200).json(produtos);
    } catch (erro) {
        next(erro);
    }
};

const atualizarProduto = async (req, res, next) => {
    try {
        const produto = await produtoService.atualizarProduto(req.params.id, req.body);
        res.json(produto);
    } catch (erro) {
        next(erro);
    }
};

const eliminarProduto = async (req, res, next) => {
    try {
        await produtoService.eliminarProduto(req.params.id);
        res.status(204).send();
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarProduto,
    listarProdutos,
    atualizarProduto,
    eliminarProduto
};
