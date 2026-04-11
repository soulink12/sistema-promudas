const prisma = require('../config/database');

const criarCliente = async (dadosCliente) => {
    const novoCliente = await prisma.clientes.create({
        data: dadosCliente
    });
    return novoCliente.id;
};

const listarClientes = async () => {
    // Busca todos os clientes onde ativo for igual a true
    const clientes = await prisma.clientes.findMany({
        where: { ativo: true }
    });
    return clientes;
};

module.exports = {
    criarCliente,
    listarClientes
};