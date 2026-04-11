const prisma = require('../config/database');

const criarVariedade = async (dados) => {
    const novaVariedade = await prisma.variedades.create({
        data: dados
    });
    return novaVariedade.id;
};

const listarVariedades = async () => {
    const variedades = await prisma.variedades.findMany({
        where: { ativo: true }
    });
    return variedades;
};

module.exports = {
    criarVariedade,
    listarVariedades
};