const prisma = require('../config/database');

// Lista os locais de entrega ativos (usado no dropdown ao registrar entregas)
const listarLocais = async () => {
    return await prisma.locais_entrega.findMany({
        where: { ativo: true },
        orderBy: { nome: 'asc' },
    });
};

module.exports = { listarLocais };
