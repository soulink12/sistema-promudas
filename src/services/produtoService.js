const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');

// Campos graváveis pela API. `ativo` fica de fora: quem controla é o
// soft-delete (eliminarProduto), não o corpo da requisição.
const CAMPOS_PRODUTO_EDITAVEIS = ['nome', 'preco'];

const filtrarCamposProduto = (dados) => Object.fromEntries(
    Object.entries(dados).filter(([chave]) => CAMPOS_PRODUTO_EDITAVEIS.includes(chave))
);

const criarProduto = async (dados) => {
    const novoProduto = await prisma.produtos.create({
        data: filtrarCamposProduto(dados)
    });
    return novoProduto.id;
};

const listarProdutos = async () => {
    return await prisma.produtos.findMany({
        orderBy: { nome: 'asc' }
    });
};

// Checa a existência antes de atualizar/excluir: sem isso, um id inexistente
// estourava P2025 e virava 500 genérico em vez de 404.
const garantirProduto = async (id) => {
    const produto = await prisma.produtos.findUnique({ where: { id: parseInt(id) } });
    if (!produto) throw new BusinessError('Produto não encontrado.', 404);
    return produto;
};

const atualizarProduto = async (id, dados) => {
    await garantirProduto(id);
    return await prisma.produtos.update({
        where: { id: parseInt(id) },
        data: filtrarCamposProduto(dados),
    });
};

const eliminarProduto = async (id) => {
    await garantirProduto(id);
    return await prisma.produtos.update({
        where: { id: parseInt(id) },
        data: { ativo: false }
    });
};

module.exports = {
    criarProduto,
    listarProdutos,
    atualizarProduto,
    eliminarProduto
};
