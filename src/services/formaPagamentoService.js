const prisma = require('../config/database');

const listarFormasPagamento = async () => {
    return await prisma.formas_pagamento.findMany({
        where: { ativo: true },
        orderBy: { nome: 'asc' },
        select: { id: true, nome: true, pagamento_posterior: true }
    });
};

module.exports = { listarFormasPagamento };
