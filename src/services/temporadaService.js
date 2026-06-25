const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');

// Lista todas as temporadas, da mais recente para a mais antiga.
const listarTemporadas = async () => {
    return await prisma.temporadas.findMany({
        orderBy: { ano: 'desc' },
    });
};

// Retorna a temporada ativa (uma só) ou null quando nenhuma está marcada.
const temporadaAtiva = async () => {
    return await prisma.temporadas.findFirst({ where: { ativo: true } });
};

// Cria uma temporada para um ano. Rejeita ano inválido ou duplicado.
const criarTemporada = async (ano) => {
    const anoInt = parseInt(ano);
    if (!Number.isInteger(anoInt) || anoInt < 2000 || anoInt > 2100) {
        throw new BusinessError('Informe um ano válido (entre 2000 e 2100).');
    }

    const existe = await prisma.temporadas.findUnique({ where: { ano: anoInt } });
    if (existe) {
        throw new BusinessError('Já existe uma temporada para esse ano.');
    }

    return await prisma.temporadas.create({ data: { ano: anoInt } });
};

// Define qual temporada está ativa — desativa todas as outras na mesma transação
// (garante que exista no máximo uma ativa).
const definirAtiva = async (id) => {
    const temporadaId = parseInt(id);
    const existe = await prisma.temporadas.findUnique({ where: { id: temporadaId } });
    if (!existe) throw new BusinessError('Temporada não encontrada.', 404);

    return await prisma.$transaction(async (tx) => {
        await tx.temporadas.updateMany({ data: { ativo: false } });
        return await tx.temporadas.update({
            where: { id: temporadaId },
            data: { ativo: true },
        });
    });
};

module.exports = { listarTemporadas, temporadaAtiva, criarTemporada, definirAtiva };
