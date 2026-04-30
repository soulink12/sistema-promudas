const prisma = require('../config/database');

const criarEntrega = async (dadosEntrega) => {
    // Extraímos os itens do corpo da requisição e mantemos o resto nos dados principais
    const { itens, ...dadosPrincipais } = dadosEntrega;

    const novaEntrega = await prisma.entregas.create({
        data: {
            ...dadosPrincipais,
            itens_entrega: {
                create: itens.map(item => ({
                    variedade_id: item.variedade_id,
                    quantidade: item.quantidade
                }))
            }
        }
    });
    return novaEntrega.id;
};

const listarEntregas = async () => {
    const entregas = await prisma.entregas.findMany({
        include: {
            itens_entrega: true, // Traz os itens (variedades e quantidades) que saíram
            encomendas: true     // Traz os dados da encomenda vinculada
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