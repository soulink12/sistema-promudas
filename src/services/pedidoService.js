const prisma = require('../config/database');

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
    return await prisma.pedidos.update({
        where: { id: parseInt(id) },
        data: dados,
    });
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
    atualizarPedido,
    eliminarPedido
};
