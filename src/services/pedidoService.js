const prisma = require('../config/database');
const { recalcularStatusPedido } = require('./pagamentoService');

const criarPedido = async (dados) => {
    return await prisma.pedidos.create({
        data: {
            clientes: {
                connect: { id: parseInt(dados.cliente_id) }
            },
            valor_total: dados.valor_total,
            ajuste: dados.ajuste ?? null,
            observacoes: dados.observacoes,
            status_geral: 'Ativa',
            ativo: true,

            itens_pedido: {
                create: dados.itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: item.valor_unitario
                }))
            }
        },
        include: {
            itens_pedido: true
        }
    });
};

const listarPedidos = async (filtros = {}) => {
    const where = { ativo: true };
    if (filtros.cliente) {
        where.clientes = { nome: { contains: filtros.cliente } };
    }

    const [pedidos, formasPosteriores] = await Promise.all([
        prisma.pedidos.findMany({
            where,
            orderBy: { criado_em: 'desc' },
            take: filtros.cliente ? 100 : 20,
            include: {
                clientes: { select: { id: true, nome: true } },
                itens_pedido: {
                    include: { produtos: { select: { nome: true } } }
                },
                pagamentos: {
                    select: {
                        id: true,
                        valor_pago: true,
                        forma_pagamento: true,
                        criado_em: true,
                    },
                    orderBy: { criado_em: 'asc' }
                },
                retiradas: {
                    include: { itens_retirada: true }
                }
            }
        }),
        prisma.formas_pagamento.findMany({
            where: { pagamento_posterior: true },
            select: { nome: true }
        })
    ]);

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));

    // Adiciona flag pagamento_posterior em cada pagamento
    return pedidos.map(pedido => ({
        ...pedido,
        pagamentos: pedido.pagamentos.map(pag => ({
            ...pag,
            pagamento_posterior: nomesPosteriores.has(pag.forma_pagamento)
        }))
    }));
};

const atualizarPedido = async (id, dados) => {
    const { itens, ...camposPedido } = dados;

    if (!itens) {
        return await prisma.pedidos.update({
            where: { id: parseInt(id) },
            data: camposPedido,
        });
    }

    const pedidoAtual = await prisma.pedidos.findUnique({
        where: { id: parseInt(id) },
        select: { ajuste: true },
    });

    const ajuste = camposPedido.ajuste !== undefined
        ? Number(camposPedido.ajuste ?? 0)
        : Number(pedidoAtual?.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    await prisma.itens_pedido.deleteMany({ where: { pedido_id: parseInt(id) } });

    const resultado = await prisma.pedidos.update({
        where: { id: parseInt(id) },
        data: {
            ...camposPedido,
            valor_total: subtotal + ajuste,
            itens_pedido: {
                create: itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: parseFloat(item.valor_unitario),
                })),
            },
        },
        include: {
            itens_pedido: {
                include: { produtos: { select: { nome: true } } },
            },
        },
    });

    await recalcularStatusPedido(id);

    return resultado;
};

const buscarPedido = async (id) => {
    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(id), ativo: true },
            include: {
                clientes: { select: { id: true, nome: true } },
                itens_pedido: {
                    include: { produtos: { select: { nome: true } } }
                },
                pagamentos: {
                    select: {
                        id: true,
                        valor_pago: true,
                        forma_pagamento: true,
                        criado_em: true,
                    },
                    orderBy: { criado_em: 'asc' }
                },
                retiradas: {
                    include: { itens_retirada: true }
                }
            }
        }),
        prisma.formas_pagamento.findMany({
            where: { pagamento_posterior: true },
            select: { nome: true }
        })
    ]);

    if (!pedido) return null;

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    return {
        ...pedido,
        pagamentos: pedido.pagamentos.map(pag => ({
            ...pag,
            pagamento_posterior: nomesPosteriores.has(pag.forma_pagamento)
        }))
    };
};

const eliminarPedido = async (id) => {
    return await prisma.pedidos.update({
        where: { id: parseInt(id) },
        data: { ativo: false }
    });
};

module.exports = {
    criarPedido,
    listarPedidos,
    buscarPedido,
    atualizarPedido,
    eliminarPedido
};
