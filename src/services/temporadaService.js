const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const logService = require('./logService');

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
const criarTemporada = async (ano, usuarioId = null) => {
    const anoInt = parseInt(ano);
    if (!Number.isInteger(anoInt) || anoInt < 2000 || anoInt > 2100) {
        throw new BusinessError('Informe um ano válido (entre 2000 e 2100).');
    }

    const existe = await prisma.temporadas.findUnique({ where: { ano: anoInt } });
    if (existe) {
        throw new BusinessError('Já existe uma temporada para esse ano.');
    }

    return await prisma.$transaction(async (tx) => {
        const temporada = await tx.temporadas.create({ data: { ano: anoInt } });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'criacao',
            entidade: 'temporada',
            entidadeId: temporada.id,
            snapshot: temporada,
        });
        return temporada;
    });
};

// Define qual temporada está ativa — desativa todas as outras na mesma transação
// (garante que exista no máximo uma ativa).
const definirAtiva = async (id, usuarioId = null) => {
    const temporadaId = parseInt(id);
    const existe = await prisma.temporadas.findUnique({ where: { id: temporadaId } });
    if (!existe) throw new BusinessError('Temporada não encontrada.', 404);

    return await prisma.$transaction(async (tx) => {
        await tx.temporadas.updateMany({ data: { ativo: false } });
        const temporada = await tx.temporadas.update({
            where: { id: temporadaId },
            data: { ativo: true },
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao',
            entidade: 'temporada',
            entidadeId: temporada.id,
            snapshot: temporada,
        });
        return temporada;
    });
};

module.exports = { listarTemporadas, temporadaAtiva, criarTemporada, definirAtiva };
