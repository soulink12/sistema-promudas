const prisma = require('../config/database');

// Recalcula o status de retirada do pedido comparando o total pedido com o total já retirado
const recalcularStatusRetirada = async (pedido_id) => {
    const pedido = await prisma.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: {
            itens_pedido: true,
            retiradas: {
                include: { itens_retirada: true }
            }
        }
    });

    if (!pedido) return;

    const totalPedido = pedido.itens_pedido.reduce((soma, item) => soma + item.quantidade, 0);

    let totalRetirado = 0;
    pedido.retiradas.forEach(retirada => {
        retirada.itens_retirada.forEach(item => {
            totalRetirado += item.quantidade;
        });
    });

    let novoStatus = 'Pendente';
    if (totalRetirado >= totalPedido) {
        novoStatus = 'Retirado';
    } else if (totalRetirado > 0) {
        novoStatus = 'Parcial';
    }

    await prisma.pedidos.update({
        where: { id: parseInt(pedido_id) },
        data: { status_retirada: novoStatus }
    });
};

// ============================================================

const criarRetirada = async (dadosRetirada) => {
    const { itens, pedido_id, ...dadosPrincipais } = dadosRetirada;

    const pedido = await prisma.pedidos.findUnique({
        where: { id: parseInt(pedido_id) },
        include: {
            itens_pedido: true,
            retiradas: {
                include: { itens_retirada: true }
            }
        }
    });

    if (!pedido) {
        throw new Error('Pedido não encontrado.');
    }

    if (pedido.ativo === false) {
        throw new Error('Não é possível registrar retiradas para um pedido desativado ou cancelado.');
    }

    // Validação de saldo por produto
    for (const itemAtual of itens) {
        const produtoId = parseInt(itemAtual.produto_id);
        const qtdSaindoAgora = parseInt(itemAtual.quantidade);

        const itemPedido = pedido.itens_pedido.find(i => i.produto_id === produtoId);
        if (!itemPedido) {
            throw new Error(`Operação bloqueada: o produto ID ${produtoId} não faz parte deste pedido.`);
        }

        let totalJaRetirado = 0;
        for (const retiradaAnterior of pedido.retiradas) {
            const itemRetirado = retiradaAnterior.itens_retirada.find(i => i.produto_id === produtoId);
            if (itemRetirado) totalJaRetirado += itemRetirado.quantidade;
        }

        const saldoRestante = itemPedido.quantidade - totalJaRetirado;

        if (qtdSaindoAgora > saldoRestante) {
            throw new Error(`Saldo insuficiente para o produto ID ${produtoId}. Restam ${saldoRestante} unidades (tentativa: ${qtdSaindoAgora}).`);
        }
    }

    const novaRetirada = await prisma.retiradas.create({
        data: {
            pedido_id: parseInt(pedido_id),
            ...dadosPrincipais,
            itens_retirada: {
                create: itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade)
                }))
            }
        }
    });

    await recalcularStatusRetirada(pedido_id);

    return novaRetirada.id;
};

const listarRetiradas = async () => {
    return await prisma.retiradas.findMany({
        where: {
            pedidos: { ativo: true }
        },
        include: {
            itens_retirada: true,
            pedidos: {
                select: {
                    id: true,
                    status_geral: true,
                    status_retirada: true,
                    cliente_id: true
                }
            }
        }
    });
};

const atualizarRetirada = async (id, dados) => {
    const retiradaId = parseInt(id);

    const retiradaOriginal = await prisma.retiradas.findUnique({
        where: { id: retiradaId },
        select: { pedido_id: true }
    });

    if (!retiradaOriginal) {
        throw new Error('Retirada não encontrada.');
    }

    const { itens, ...dadosPrincipais } = dados;

    if (itens && Array.isArray(itens)) {
        const pedido = await prisma.pedidos.findUnique({
            where: { id: retiradaOriginal.pedido_id },
            include: { itens_pedido: true }
        });

        const outrasRetiradas = await prisma.retiradas.findMany({
            where: {
                pedido_id: retiradaOriginal.pedido_id,
                id: { not: retiradaId }
            },
            include: { itens_retirada: true }
        });

        const jaRetirado = {};
        outrasRetiradas.forEach(ret => {
            ret.itens_retirada.forEach(item => {
                jaRetirado[item.produto_id] = (jaRetirado[item.produto_id] || 0) + item.quantidade;
            });
        });

        for (const novoItem of itens) {
            const itemPedido = pedido.itens_pedido.find(i => i.produto_id === novoItem.produto_id);
            const totalPedido = itemPedido ? itemPedido.quantidade : 0;

            if (totalPedido === 0) {
                throw new Error(`O produto ID ${novoItem.produto_id} não faz parte deste pedido.`);
            }

            const saldoDisponivel = totalPedido - (jaRetirado[novoItem.produto_id] || 0);

            if (novoItem.quantidade > saldoDisponivel) {
                throw new Error(`Saldo insuficiente para o produto ID ${novoItem.produto_id}. Máximo permitido: ${saldoDisponivel}.`);
            }
        }
    }

    let dataParaAtualizar = { ...dadosPrincipais };

    if (itens && Array.isArray(itens)) {
        dataParaAtualizar.itens_retirada = {
            deleteMany: {},
            create: itens.map(item => ({
                produto_id: item.produto_id,
                quantidade: item.quantidade
            }))
        };
    }

    const retiradaAtualizada = await prisma.retiradas.update({
        where: { id: retiradaId },
        data: dataParaAtualizar
    });

    await recalcularStatusRetirada(retiradaOriginal.pedido_id);

    return retiradaAtualizada;
};

const eliminarRetirada = async (id) => {
    const retirada = await prisma.retiradas.findUnique({
        where: { id: parseInt(id) }
    });

    if (!retirada) {
        throw new Error('Retirada não encontrada.');
    }

    const resultado = await prisma.retiradas.delete({
        where: { id: parseInt(id) }
    });

    await recalcularStatusRetirada(retirada.pedido_id);

    return resultado;
};

module.exports = {
    criarRetirada,
    listarRetiradas,
    atualizarRetirada,
    eliminarRetirada
};
