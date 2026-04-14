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

const atualizarCliente = async (id, dados) => {
  return await prisma.clientes.update({
    where: { id: parseInt(id) },
    data: dados,
  });
};

const eliminarCliente = async (id) => {
  return await prisma.clientes.update({
    where: { id: parseInt(id) },
    data: {ativo: false}
  });
};

module.exports = {
    criarCliente,
    listarClientes,
    atualizarCliente,
    eliminarCliente
};