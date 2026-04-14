const prisma = require('../config/database');

const criarEncomenda = async (dados) => {
  return await prisma.encomendas.create({
    data: {
      // Conecta com o cliente existente
      clientes: {
        connect: { id: parseInt(dados.cliente_id) }
      },
      valor_total: dados.valor_total,
      observacoes: dados.observacoes,
      status_geral: "Ativa",
      ativo: true,
      
      // Cria os itens automaticamente na tabela itens_encomenda
      itens_encomenda: {
        create: dados.itens.map(item => ({
          variedade_id: parseInt(item.variedade_id),
          quantidade: parseInt(item.quantidade),
          valor_unitario: item.valor_unitario
        }))
      }
    },
    // Isso faz com que o retorno já venha com os itens incluídos para conferência
    include: {
      itens_encomenda: true
    }
  });
};

const listarEncomendas = async () => {
  return await prisma.encomendas.findMany({
    where: { ativo: true },
    include: {
      clientes: { select: { nome: true } },
      itens_encomenda: {
        include: { variedades: { select: { nome: true } } }
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