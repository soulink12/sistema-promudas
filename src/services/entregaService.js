const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { parseData, normalizarDatas } = require('../utils/parseData');

// Recalcula o status de entrega do pedido comparando o total pedido com o total já entregue
const recalcularStatusEntrega = async (pedido_id) => {
    const pedido = await prisma.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: {
            itens_pedido: true,
            entregas: {
                include: { itens_entrega: true }
            }
        }
    });

    if (!pedido) return;

    const totalPedido = pedido.itens_pedido.reduce((soma, item) => soma + item.quantidade, 0);

    let totalEntregue = 0;
    pedido.entregas.forEach(entrega => {
        entrega.itens_entrega.forEach(item => {
            totalEntregue += item.quantidade;
        });
    });

    let novoStatus = 'Pendente';
    if (totalEntregue >= totalPedido) {
        novoStatus = 'Entregue';
    } else if (totalEntregue > 0) {
        novoStatus = 'Parcial';
    }

    await prisma.pedidos.update({
        where: { id: parseInt(pedido_id) },
        data: { status_entrega: novoStatus }
    });
};

// ============================================================

const criarEntrega = async (dadosEntrega) => {
    const { itens, pedido_id, ...dadosPrincipais } = dadosEntrega;

    const pedido = await prisma.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: {
            itens_pedido: true,
            entregas: {
                include: { itens_entrega: true }
            }
        }
    });

    if (!pedido) {
        throw new BusinessError('Pedido não encontrado.', 404);
    }

    if (pedido.ativo === false) {
        throw new BusinessError('Não é possível registrar entregas para um pedido desativado ou cancelado.');
    }

    // Validação de saldo por produto
    for (const itemAtual of itens) {
        const produtoId = parseInt(itemAtual.produto_id);
        const qtdSaindoAgora = parseInt(itemAtual.quantidade);

        const itemPedido = pedido.itens_pedido.find(i => i.produto_id === produtoId);
        if (!itemPedido) {
            throw new BusinessError(`Operação bloqueada: o produto ID ${produtoId} não faz parte deste pedido.`);
        }

        let totalJaEntregue = 0;
        for (const entregaAnterior of pedido.entregas) {
            const itemEntregue = entregaAnterior.itens_entrega.find(i => i.produto_id === produtoId);
            if (itemEntregue) totalJaEntregue += itemEntregue.quantidade;
        }

        const saldoRestante = itemPedido.quantidade - totalJaEntregue;

        if (qtdSaindoAgora > saldoRestante) {
            throw new BusinessError(`Saldo insuficiente para o produto ID ${produtoId}. Restam ${saldoRestante} unidades (tentativa: ${qtdSaindoAgora}).`);
        }
    }

    const novaEntrega = await prisma.entregas.create({
        data: {
            pedido_id: parseInt(pedido_id),
            ...dadosPrincipais,
            // Na criação, a data da entrega é o momento atual (= criado_em).
            // Pode ser alterada depois na consulta (PUT /entregas/:id).
            data_entrega: parseData(dadosPrincipais.data_entrega, 'data_entrega') ?? new Date(),
            itens_entrega: {
                create: itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade)
                }))
            }
        }
    });

    await recalcularStatusEntrega(pedido_id);

    return novaEntrega.id;
};

const listarEntregas = async (filtros = {}) => {
    const wherePedido = { ativo: true };
    if (filtros.cliente) {
        wherePedido.clientes = { nome: { contains: filtros.cliente } };
    }

    return await prisma.entregas.findMany({
        where: {
            pedidos: wherePedido
        },
        orderBy: { criado_em: 'desc' },
        take: 20,
        include: {
            itens_entrega: {
                include: { produtos: { select: { nome: true } } }
            },
            pedidos: {
                select: {
                    id: true,
                    temporada_ano: true,
                    numero_temporada: true,
                    status_geral: true,
                    status_entrega: true,
                    cliente_id: true,
                    clientes: { select: { id: true, nome: true } }
                }
            }
        }
    });
};

const atualizarEntrega = async (id, dados) => {
    const entregaId = parseInt(id);

    const entregaOriginal = await prisma.entregas.findUnique({
        where: { id: entregaId },
        select: { pedido_id: true }
    });

    if (!entregaOriginal) {
        throw new BusinessError('Entrega não encontrada.', 404);
    }

    const { itens, ...dadosPrincipais } = dados;

    if (itens && Array.isArray(itens)) {
        const pedido = await prisma.pedidos.findUnique({
            where: { id: entregaOriginal.pedido_id },
            include: { itens_pedido: true }
        });

        const outrasEntregas = await prisma.entregas.findMany({
            where: {
                pedido_id: entregaOriginal.pedido_id,
                id: { not: entregaId }
            },
            include: { itens_entrega: true }
        });

        const jaEntregue = {};
        outrasEntregas.forEach(ret => {
            ret.itens_entrega.forEach(item => {
                jaEntregue[item.produto_id] = (jaEntregue[item.produto_id] || 0) + item.quantidade;
            });
        });

        for (const novoItem of itens) {
            const itemPedido = pedido.itens_pedido.find(i => i.produto_id === novoItem.produto_id);
            const totalPedido = itemPedido ? itemPedido.quantidade : 0;

            if (totalPedido === 0) {
                throw new BusinessError(`O produto ID ${novoItem.produto_id} não faz parte deste pedido.`);
            }

            const saldoDisponivel = totalPedido - (jaEntregue[novoItem.produto_id] || 0);

            if (novoItem.quantidade > saldoDisponivel) {
                throw new BusinessError(`Saldo insuficiente para o produto ID ${novoItem.produto_id}. Máximo permitido: ${saldoDisponivel}.`);
            }
        }
    }

    let dataParaAtualizar = normalizarDatas(dadosPrincipais, ['data_entrega']);

    if (itens && Array.isArray(itens)) {
        dataParaAtualizar.itens_entrega = {
            deleteMany: {},
            create: itens.map(item => ({
                produto_id: item.produto_id,
                quantidade: item.quantidade
            }))
        };
    }

    const entregaAtualizada = await prisma.entregas.update({
        where: { id: entregaId },
        data: dataParaAtualizar
    });

    await recalcularStatusEntrega(entregaOriginal.pedido_id);

    return entregaAtualizada;
};

const eliminarEntrega = async (id) => {
    const entrega = await prisma.entregas.findUnique({
        where: { id: parseInt(id) }
    });

    if (!entrega) {
        throw new BusinessError('Entrega não encontrada.', 404);
    }

    const resultado = await prisma.entregas.delete({
        where: { id: parseInt(id) }
    });

    await recalcularStatusEntrega(entrega.pedido_id);

    return resultado;
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega,
    recalcularStatusEntrega
};
