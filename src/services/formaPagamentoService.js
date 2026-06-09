const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');

const listarFormasPagamento = async () => {
    return await prisma.formas_pagamento.findMany({
        orderBy: { nome: 'asc' },
        select: { id: true, nome: true, ativo: true, pagamento_posterior: true }
    });
};

const criarForma = async (nome, pagamentoPosterior = false) => {
    return await prisma.formas_pagamento.create({
        data: { nome, pagamento_posterior: pagamentoPosterior }
    });
};

const atualizarForma = async (id, dados) => {
    const existe = await prisma.formas_pagamento.findUnique({ where: { id } });
    if (!existe) throw new BusinessError('Forma de pagamento não encontrada.', 404);
    return await prisma.formas_pagamento.update({
        where: { id },
        data: dados
    });
};

const deletarForma = async (id) => {
    const existe = await prisma.formas_pagamento.findUnique({ where: { id } });
    if (!existe) throw new BusinessError('Forma de pagamento não encontrada.', 404);
    await prisma.formas_pagamento.update({ where: { id }, data: { ativo: false } });
};

module.exports = { listarFormasPagamento, criarForma, atualizarForma, deletarForma };
