const prisma = require('../config/database');

const criarEncomenda = async (dados) => {
    // Usamos o 'clientes' (nome do objeto no seu schema) para conectar o ID
    // E 'itens_encomenda' para criar o registro da muda/quantidade simultaneamente
    const novaEncomenda = await prisma.encomendas.create({
        data: {
            valor_total: dados.valor_total,
            status_geral: dados.status_geral || "Ativa",
            status_pagamento: "Pendente",
            status_entrega: "Pendente",
            
            // CONEXÃO COM CLIENTE (O Prisma exige o nome da relação 'clientes')
            clientes: {
                connect: { id: parseInt(dados.cliente_id) }
            },

            // CRIAÇÃO DO ITEM (Onde realmente fica a quantidade e a muda no seu schema)
            itens_encomenda: {
                create: [
                  {
                    quantidade: parseInt(dados.quantidade),
                    variedades: {
                      connect: { id: parseInt(dados.variedade_id) }
                    }
                  }
                ]
            }
        }
    });
    
    return novaEncomenda.id;
};

const listarEncomendas = async () => {
    // Retorna a encomenda com os dados do cliente e os itens inclusos
    return await prisma.encomendas.findMany({
        where: { ativo: true },
        include: {
            clientes: true,
            itens_encomenda: {
                include: {
                    variedades: true
                }
            }
        }
    });
};

const atualizarEncomenda = async (id, dados) => {
  return await prisma.encomendas.update({
    where: { id: parseInt(id) },
    data: dados,
  });
};

const eliminarEncomenda = async (id) => {
  // O Prisma apagará os itens se estiver configurado o CASCADE no banco
  return await prisma.encomendas.update({
    where: { id: parseInt(id) },
    data: {ativo: false}
  });
};

module.exports = {
    criarEncomenda,
    listarEncomendas,
    atualizarEncomenda,
    eliminarEncomenda
};