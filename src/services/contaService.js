const prisma = require('../config/database');

// Lista as contas ativas (usado no dropdown ao registrar pagamentos no PDV)
const listarContas = async () => {
    return await prisma.contas.findMany({
        where: { ativo: true },
        orderBy: { nome: 'asc' },
    });
};

module.exports = { listarContas };
