const prisma = require('../config/database');

const criarPagamento = async (dadosPagamento) => {
    // Se a data vier no formato de string, o Prisma converte automaticamente 
    // desde que esteja no formato ISO (ex: "2026-04-30T00:00:00.000Z")
    const novoPagamento = await prisma.pagamentos.create({
        data: dadosPagamento
    });
    return novoPagamento.id;
};

const listarPagamentos = async () => {
    // Como não tem campo "ativo", listamos todos (ou podemos filtrar por encomenda no futuro)
    const pagamentos = await prisma.pagamentos.findMany({
        include: {
            encomendas: true // Traz os dados da encomenda vinculada (opcional, mas muito útil)
        }
    });
    return pagamentos;
};

const atualizarPagamento = async (id, dados) => {
    return await prisma.pagamentos.update({
        where: { id: parseInt(id) },
        data: dados,
    });
};

const eliminarPagamento = async (id) => {
    // Como não existe o campo "ativo", fazemos a exclusão real do registo
    return await prisma.pagamentos.delete({
        where: { id: parseInt(id) }
    });
};

module.exports = {
    criarPagamento,
    listarPagamentos,
    atualizarPagamento,
    eliminarPagamento
};