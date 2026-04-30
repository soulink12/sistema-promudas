const prisma = require('../config/database');

const criarEntrega = async (dadosEntrega) => {
    const { itens, encomenda_id, ...dadosPrincipais } = dadosEntrega;

    // 1. Busca a encomenda trazendo o que foi encomendado e o histórico de entregas
    const encomenda = await prisma.encomendas.findUnique({
        where: { id: parseInt(encomenda_id) },
        include: {
            itens_encomenda: true, // O que o cliente comprou originalmente
            entregas: {            // Entregas passadas
                include: {
                    itens_entrega: true // Detalhes do que já saiu
                }
            }
        }
    });

    if (!encomenda) {
        throw new Error('Encomenda não encontrada.');
    }

    if (encomenda.ativo === false) {
        throw new Error('Não é possível registar entregas para uma encomenda desativada ou cancelada.');
    }

    // 2. VALIDAÇÃO DE SALDO DE MUDAS
    for (const itemAtual of itens) {
        const variedadeId = parseInt(itemAtual.variedade_id);
        const qtdSaindoAgora = parseInt(itemAtual.quantidade);

        // A. Verifica se o cliente realmente comprou esta variedade na encomenda
        const itemComprado = encomenda.itens_encomenda.find(i => i.variedade_id === variedadeId);
        if (!itemComprado) {
            throw new Error(`Operação bloqueada: A variedade ID ${variedadeId} não faz parte desta encomenda.`);
        }

        const totalComprado = itemComprado.quantidade;

        // B. Soma quantas mudas dessa variedade já saíram em entregas anteriores
        let totalJaEntregue = 0;
        for (const entregaAntiga of encomenda.entregas) {
            const itemEntregue = entregaAntiga.itens_entrega.find(i => i.variedade_id === variedadeId);
            if (itemEntregue) {
                totalJaEntregue += itemEntregue.quantidade;
            }
        }

        const saldoRestante = totalComprado - totalJaEntregue;

        // C. Bloqueia se tentar enviar mais do que o saldo permite
        if (qtdSaindoAgora > saldoRestante) {
            throw new Error(`Atenção: Saldo insuficiente para a variedade ID ${variedadeId}. Restam apenas ${saldoRestante} mudas para entrega (Tentativa de enviar ${qtdSaindoAgora}).`);
        }
    }

    // 3. Se passou em todas as validações, cria a entrega no banco
    const novaEntrega = await prisma.entregas.create({
        data: {
            encomenda_id: parseInt(encomenda_id),
            ...dadosPrincipais,
            itens_entrega: {
                create: itens.map(item => ({
                    variedade_id: parseInt(item.variedade_id),
                    quantidade: parseInt(item.quantidade)
                }))
            }
        }
    });

    return novaEntrega.id;
};

const listarEntregas = async () => {
    const entregas = await prisma.entregas.findMany({
        where: {
            encomendas: {
                ativo: true
            }
        },
        include: {
            itens_entrega: true,
            encomendas: {
                select: {
                    id: true,
                    status_geral: true,
                    status_entrega: true,
                    cliente_id: true
                }
            }
        }
    });
    return entregas;
};

const atualizarEntrega = async (id, dados) => {
    // Nota: Para atualizar itens aninhados é mais complexo, 
    // então esta rota atualiza apenas os dados principais (ex: status, motorista, etc)
    return await prisma.entregas.update({
        where: { id: parseInt(id) },
        data: dados,
    });
};

const eliminarEntrega = async (id) => {
    // O Prisma vai apagar a entrega e, devido ao "onDelete: Cascade" no schema,
    // os "itens_entrega" vinculados a ela também serão apagados automaticamente.
    return await prisma.entregas.delete({
        where: { id: parseInt(id) }
    });
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega
};