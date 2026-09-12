const prisma = require('../config/database');
const logService = require('./logService');
const BusinessError = require('../utils/BusinessError');

const INTERESSADO_INCLUDE = {
    clientes: { select: { id: true, nome: true, email: true } },
    itens_interesse: {
        include: { produtos: { select: { nome: true } } }
    }
};

const criarInteressado = async (dados, usuarioId = null) => {
    return await prisma.$transaction(async (tx) => {
        const interessado = await tx.interessados.create({
            data: {
                clientes: {
                    connect: { id: parseInt(dados.cliente_id) }
                },
                observacoes: dados.observacoes,
                ativo: true,

                itens_interesse: {
                    create: dados.itens.map(item => ({
                        produto_id: parseInt(item.produto_id),
                        quantidade: parseInt(item.quantidade),
                    }))
                }
            },
            // Mesmo formato usado nas demais snapshots (INTERESSADO_INCLUDE) —
            // sem isso, o diff de histórico compararia itens com/sem
            // `produtos.nome` e marcaria todo item como "alterado" só pela
            // forma do JSON, não pelo conteúdo (mesmo cuidado de orcamentoService).
            include: {
                itens_interesse: {
                    include: { produtos: { select: { nome: true } } }
                }
            }
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'criacao',
            entidade: 'interessado',
            entidadeId: interessado.id,
            snapshot: interessado,
        });

        return interessado;
    });
};

const listarInteressados = async (filtros = {}) => {
    const where = { ativo: true };
    if (filtros.cliente) {
        where.clientes = { nome: { contains: filtros.cliente } };
    }

    return await prisma.interessados.findMany({
        where,
        orderBy: { criado_em: 'desc' },
        include: INTERESSADO_INCLUDE
    });
};

const buscarInteressado = async (id) => {
    return await prisma.interessados.findUnique({
        where: { id: parseInt(id), ativo: true },
        include: INTERESSADO_INCLUDE
    });
};

// Edita um interessado (cliente, itens, observações). Itens são sempre
// substituídos por completo quando informados, como em orcamentoService.
const atualizarInteressado = async (id, dados, usuarioId = null) => {
    const interessadoAtual = await prisma.interessados.findUnique({
        where: { id: parseInt(id) },
        select: { id: true },
    });
    if (!interessadoAtual) {
        throw new BusinessError('Interessado não encontrado.', 404);
    }

    const { itens, cliente_id, observacoes } = dados;
    const camposInteressado = {
        ...(cliente_id !== undefined && { cliente_id: parseInt(cliente_id) }),
        ...(observacoes !== undefined && { observacoes }),
    };

    if (!itens) {
        return await prisma.$transaction(async (tx) => {
            const interessado = await tx.interessados.update({
                where: { id: parseInt(id) },
                data: camposInteressado,
                include: INTERESSADO_INCLUDE,
            });
            await logService.registrarAtividade(tx, {
                usuarioId,
                acao: 'atualizacao',
                entidade: 'interessado',
                entidadeId: interessado.id,
                snapshot: interessado,
            });
            return interessado;
        });
    }

    return await prisma.$transaction(async (tx) => {
        await tx.itens_interesse.deleteMany({ where: { interessado_id: parseInt(id) } });

        const interessado = await tx.interessados.update({
            where: { id: parseInt(id) },
            data: {
                ...camposInteressado,
                itens_interesse: {
                    create: itens.map(item => ({
                        produto_id: parseInt(item.produto_id),
                        quantidade: parseInt(item.quantidade),
                    })),
                },
            },
            include: INTERESSADO_INCLUDE,
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao',
            entidade: 'interessado',
            entidadeId: interessado.id,
            snapshot: interessado,
        });

        return interessado;
    });
};

const eliminarInteressado = async (id, usuarioId = null) => {
    return await prisma.$transaction(async (tx) => {
        const interessado = await tx.interessados.update({
            where: { id: parseInt(id) },
            data: { ativo: false },
            include: { itens_interesse: { include: { produtos: { select: { nome: true } } } } },
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'exclusao',
            entidade: 'interessado',
            entidadeId: interessado.id,
            snapshot: interessado,
        });
        return interessado;
    });
};

module.exports = {
    criarInteressado,
    listarInteressados,
    buscarInteressado,
    atualizarInteressado,
    eliminarInteressado,
};
