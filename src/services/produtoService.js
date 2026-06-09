const prisma = require('../config/database');

const criarProduto = async (dados) => {
    const novoProduto = await prisma.produtos.create({
        data: dados
    });
    return novoProduto.id;
};

const listarProdutos = async () => {
    return await prisma.produtos.findMany({
        orderBy: { nome: 'asc' }
    });
};

const atualizarProduto = async (id, dados) => {
    return await prisma.produtos.update({
        where: { id: parseInt(id) },
        data: dados,
    });
};

const eliminarProduto = async (id) => {
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
