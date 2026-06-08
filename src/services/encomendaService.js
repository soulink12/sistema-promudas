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

const listarPedidos = async () => {
    return await prisma.pedidos.findMany({
        where: { ativo: true },
        include: {
            clientes: { select: { nome: true } },
            itens_pedido: {
                include: { produtos: { select: { nome: true } } }
            }
        }
    });
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
