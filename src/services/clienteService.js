const prisma = require('../config/database');

const criarCliente = async (dadosCliente) => {
    const novoCliente = await prisma.clientes.create({
        data: dadosCliente
    });
    return novoCliente.id;
};

const listarClientes = async (filtros = {}) => {
    const where = { ativo: true };

    // Pesquisa por nome, CPF/CNPJ ou telefone
    if (filtros.busca) {
        where.OR = [
            { nome: { contains: filtros.busca } },
            { cpf_cnpj: { contains: filtros.busca } },
            { telefone_1: { contains: filtros.busca } },
        ];
    }

    // Sem busca: retorna só os 20 últimos cadastrados.
    // Com busca: retorna todos os resultados encontrados.
    const clientes = await prisma.clientes.findMany({
        where,
        orderBy: { id: 'desc' },
        take: filtros.busca ? undefined : 20,
    });
    return clientes;
};

const buscarCliente = async (id) => {
    return await prisma.clientes.findUnique({
        where: { id: parseInt(id) }
    });
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
    buscarCliente,
    atualizarCliente,
    eliminarCliente
};