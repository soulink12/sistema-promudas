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
    // Filtra por status de entrega (ex.: 'Pendente,Parcial') quando informado
    if (filtros.statusEntrega) {
        where.status_entrega = { in: filtros.statusEntrega.split(',') };
    }
    // Filtra por status de pagamento (ex.: 'Pendente,Parcial') quando informado
    if (filtros.statusPagamento) {
        where.status_pagamento = { in: filtros.statusPagamento.split(',') };
    }

    const [pedidos, formasPosteriores] = await Promise.all([
        prisma.pedidos.findMany({
            where,
            orderBy: { criado_em: 'desc' },
            take: (filtros.cliente || filtros.statusPagamento) ? 100 : 20,
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
                        parcelas: true,
                        conta: true,
                        nome_pagador: true,
                        cpf_cnpj_pagador: true,
                        status_nota: true,
                        numero_nota: true,
                        data_emissao_nota: true,
                        criado_em: true,
                    },
                    orderBy: { criado_em: 'asc' }
                },
                entregas: {
                    include: { itens_entrega: true }
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

    const [pedidoAtual, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(id) },
            select: {
                ajuste: true,
                cliente_id: true,
                pagamentos: { select: { valor_pago: true, forma_pagamento: true } },
            },
        }),
        prisma.formas_pagamento.findMany({
            where: { pagamento_posterior: true },
            select: { nome: true },
        }),
    ]);

    const ajuste = camposPedido.ajuste !== undefined
        ? Number(camposPedido.ajuste ?? 0)
        : Number(pedidoAtual?.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const totalPagoReal = (pedidoAtual?.pagamentos ?? [])
        .filter(p => !nomesPosteriores.has(p.forma_pagamento))
        .reduce((s, p) => s + parseFloat(p.valor_pago), 0);

    const novoTotal = subtotal + ajuste;
    const creditoGerado = Math.max(0, totalPagoReal - novoTotal);

    if (creditoGerado > 0.01 && pedidoAtual?.cliente_id) {
        await prisma.clientes.update({
            where: { id: pedidoAtual.cliente_id },
            data: { saldo_credito: { increment: creditoGerado } },
        });
    }

    await prisma.itens_pedido.deleteMany({ where: { pedido_id: parseInt(id) } });

    const resultado = await prisma.pedidos.update({
        where: { id: parseInt(id) },
        data: {
            ...camposPedido,
            valor_total: novoTotal,
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

    return { ...resultado, creditoGerado };
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
                        parcelas: true,
                        conta: true,
                        nome_pagador: true,
                        cpf_cnpj_pagador: true,
                        status_nota: true,
                        numero_nota: true,
                        data_emissao_nota: true,
                        criado_em: true,
                    },
                    orderBy: { criado_em: 'asc' }
                },
                entregas: {
                    include: { itens_entrega: true }
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
