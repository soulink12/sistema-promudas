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

const atualizarVariedade = async (id, dados) => {
  return await prisma.variedades.update({
    where: { id: parseInt(id) },
    data: dados,
  });
};

const eliminarVariedade = async (id) => {
  return await prisma.variedades.update({
    where: { id: parseInt(id) },
    data: {ativo: false}
  });
};

module.exports = {
    criarVariedade,
    listarVariedades,
    atualizarVariedade,
    eliminarVariedade
};