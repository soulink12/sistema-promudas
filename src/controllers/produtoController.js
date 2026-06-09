const produtoService = require('../services/produtoService');

const criarProduto = async (req, res) => {
    try {
        const dados = req.body;

        if (!dados.nome || dados.preco === undefined) {
            return res.status(400).json({ erro: 'Nome e preço do produto são obrigatórios.' });
        }

        const novoId = await produtoService.criarProduto(dados);
        return res.status(201).json({ mensagem: 'Produto cadastrado com sucesso!', id: novoId });

    } catch (error) {
        console.error('Erro ao criar produto:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const listarProdutos = async (req, res) => {
    try {
        const produtos = await produtoService.listarProdutos();
        return res.status(200).json(produtos);
    } catch (error) {
        console.error('Erro ao buscar produtos:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const atualizarProduto = async (req, res) => {
    try {
        const produto = await produtoService.atualizarProduto(req.params.id, req.body);
        res.json(produto);
    } catch (error) {
        res.status(500).json({ erro: 'Erro ao atualizar produto.' });
    }
};

const eliminarProduto = async (req, res) => {
    try {
        await produtoService.eliminarProduto(req.params.id);
        res.status(204).send();
    } catch (error) {
        res.status(500).json({ erro: 'Erro ao eliminar produto.' });
    }
};

module.exports = {
    criarProduto,
    listarProdutos,
    atualizarProduto,
    eliminarProduto
};
