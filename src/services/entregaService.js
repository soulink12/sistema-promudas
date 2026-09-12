const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { parseData, normalizarDatas } = require('../utils/parseData');
const logService = require('./logService');

// Recalcula o status de entrega do pedido comparando o total pedido com o total já entregue.
// `usuarioId` é repassado de quem disparou o recálculo — só gera uma entrada de log quando o
// status realmente muda, mesmo padrão de pagamentoService.recalcularStatusPedido.
const recalcularStatusEntrega = async (pedido_id, usuarioId = null) => {
    await prisma.$transaction(async (tx) => {
        // Lê o pedido (e o status atual) DENTRO da transação — mesma razão
        // documentada em pagamentoService.recalcularStatusPedido: fecha a
        // janela de corrida entre ler o status e gravar o novo quando duas
        // ações no mesmo pedido (ex.: duas entregas quase simultâneas)
        // disparam o recálculo em paralelo.
        const pedido = await tx.pedidos.findUnique({
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

        // Nada mudou: não escreve nem loga (evita transação/consulta extra
        // — a busca de itens_pedido+produtos abaixo só compensa quando o
        // status realmente vai mudar e precisa entrar no snapshot do log).
        if (novoStatus === pedido.status_entrega) return;

        // Mesmo formato de itens usado nas demais snapshots de pedido — sem
        // isso, o diff de histórico não teria como comparar itens_pedido
        // contra este evento (campo ausente aqui = comparação pulada).
        const atualizado = await tx.pedidos.update({
            where: { id: parseInt(pedido_id) },
            data: { status_entrega: novoStatus },
            include: { itens_pedido: { include: { produtos: { select: { nome: true } } } } },
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao_automatica',
            entidade: 'pedido',
            entidadeId: atualizado.id,
            snapshot: atualizado,
        });
    });
};

// ============================================================

const criarEntrega = async (dadosEntrega, usuarioId = null) => {
    const { itens, pedido_id, ...dadosPrincipais } = dadosEntrega;

    const novaEntrega = await prisma.$transaction(async (tx) => {
        const pedido = await tx.pedidos.findUnique({
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

        const entrega = await tx.entregas.create({
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
            },
            // Sem isso o snapshot do histórico não traz quais produtos saíram
            // nesta entrega (mesmo motivo do include em pedido/orçamento).
            include: { itens_entrega: { include: { produtos: { select: { nome: true } } } } },
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'criacao',
            entidade: 'entrega',
            entidadeId: entrega.id,
            snapshot: entrega,
        });

        return entrega;
    });

    await recalcularStatusEntrega(pedido_id, usuarioId);

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

const atualizarEntrega = async (id, dados, usuarioId = null) => {
    const entregaId = parseInt(id);
    const { itens, ...dadosPrincipais } = dados;
    let dataParaAtualizar = normalizarDatas(dadosPrincipais, ['data_entrega']);

    const { entregaAtualizada, pedido_id } = await prisma.$transaction(async (tx) => {
        const entregaOriginal = await tx.entregas.findUnique({
            where: { id: entregaId },
            select: { pedido_id: true }
        });

        if (!entregaOriginal) {
            throw new BusinessError('Entrega não encontrada.', 404);
        }

        if (itens && Array.isArray(itens)) {
            const pedido = await tx.pedidos.findUnique({
                where: { id: entregaOriginal.pedido_id },
                include: { itens_pedido: true }
            });

            const outrasEntregas = await tx.entregas.findMany({
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

            dataParaAtualizar.itens_entrega = {
                deleteMany: {},
                create: itens.map(item => ({
                    produto_id: item.produto_id,
                    quantidade: item.quantidade
                }))
            };
        }

        const entregaAtualizada = await tx.entregas.update({
            where: { id: entregaId },
            data: dataParaAtualizar,
            // Ver comentário em criarEntrega — sem isso o diff nunca detecta
            // troca de produto/quantidade entregue, mesmo quando `itens` foi
            // enviado e as linhas foram apagadas/recriadas acima.
            include: { itens_entrega: { include: { produtos: { select: { nome: true } } } } },
        });

        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'atualizacao',
            entidade: 'entrega',
            entidadeId: entregaAtualizada.id,
            snapshot: entregaAtualizada,
        });

        return { entregaAtualizada, pedido_id: entregaOriginal.pedido_id };
    });

    await recalcularStatusEntrega(pedido_id, usuarioId);

    return entregaAtualizada;
};

const eliminarEntrega = async (id, usuarioId = null) => {
    const entrega = await prisma.entregas.findUnique({
        where: { id: parseInt(id) }
    });

    if (!entrega) {
        throw new BusinessError('Entrega não encontrada.', 404);
    }

    const resultado = await prisma.$transaction(async (tx) => {
        const excluida = await tx.entregas.delete({
            where: { id: parseInt(id) },
            // Ver comentário em criarEntrega — registra quais produtos
            // estavam nesta entrega antes de excluí-la.
            include: { itens_entrega: { include: { produtos: { select: { nome: true } } } } },
        });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'exclusao',
            entidade: 'entrega',
            entidadeId: excluida.id,
            snapshot: excluida,
        });
        return excluida;
    });

    await recalcularStatusEntrega(entrega.pedido_id, usuarioId);

    return resultado;
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega,
    recalcularStatusEntrega
};
