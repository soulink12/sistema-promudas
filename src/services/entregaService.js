const prisma = require('../config/database');

/**
 * FUNÇÃO DE AUTOMAÇÃO (INTERNA)
 * Recalcula o status de entrega da encomenda comparando o total de mudas 
 * compradas com o total de mudas já entregues em todas as viagens.
 */
const recalcularStatusEntrega = async (encomenda_id) => {
    // 1. Busca a encomenda com todos os itens comprados e o histórico de entregas (e itens entregues)
    const encomenda = await prisma.encomendas.findUnique({
        where: { id: parseInt(encomenda_id) },
        include: {
            itens_encomenda: true,
            entregas: {
                include: {
                    itens_entrega: true
                }
            }
        }
    });

    if (!encomenda) return;

    // 2. Soma o total de mudas COMPRADAS (juntando todas as variedades)
    const totalComprado = encomenda.itens_encomenda.reduce((soma, item) => {
        return soma + item.quantidade;
    }, 0);

    // 3. Soma o total de mudas ENTREGUES (juntando todas as viagens e variedades)
    let totalEntregue = 0;
    encomenda.entregas.forEach(entrega => {
        entrega.itens_entrega.forEach(item => {
            totalEntregue += item.quantidade;
        });
    });

    // 4. Define o status logicamente
    let novoStatus = 'Pendente';
    
    if (totalEntregue >= totalComprado) {
        novoStatus = 'Entregue';
    } else if (totalEntregue > 0) {
        novoStatus = 'Parcial';
    }

    // 5. Sincroniza o novo status com a tabela de encomendas
    await prisma.encomendas.update({
        where: { id: parseInt(encomenda_id) },
        data: { status_entrega: novoStatus }
    });
};

// ============================================================
// SERVIÇOS DE ENTREGA
// ============================================================

const criarEntrega = async (dadosEntrega) => {
    const { itens, encomenda_id, ...dadosPrincipais } = dadosEntrega;

    // 1. Busca a encomenda trazendo o que foi encomendado e o histórico de entregas
    const encomenda = await prisma.encomendas.findUnique({
        where: { id: parseInt(encomenda_id) },
        include: {
            itens_encomenda: true, 
            entregas: {            
                include: {
                    itens_entrega: true 
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

        const itemComprado = encomenda.itens_encomenda.find(i => i.variedade_id === variedadeId);
        if (!itemComprado) {
            throw new Error(`Operação bloqueada: A variedade ID ${variedadeId} não faz parte desta encomenda.`);
        }

        const totalComprado = itemComprado.quantidade;

        let totalJaEntregue = 0;
        for (const entregaAntiga of encomenda.entregas) {
            const itemEntregue = entregaAntiga.itens_entrega.find(i => i.variedade_id === variedadeId);
            if (itemEntregue) {
                totalJaEntregue += itemEntregue.quantidade;
            }
        }

        const saldoRestante = totalComprado - totalJaEntregue;

        if (qtdSaindoAgora > saldoRestante) {
            throw new Error(`Atenção: Saldo insuficiente para a variedade ID ${variedadeId}. Restam apenas ${saldoRestante} mudas para entrega (Tentativa de enviar ${qtdSaindoAgora}).`);
        }
    }

    // 3. Cria a entrega no banco
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

    // 4. AUTOMAÇÃO: Dispara o recálculo após criar a entrega
    await recalcularStatusEntrega(encomenda_id);

    return novaEntrega.id;
};

const listarEntregas = async () => {
    const entregas = await prisma.entregas.findMany({
        where: {
            encomendas: { ativo: true }
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
  // 1. Extraímos os 'itens' e guardamos o resto (motorista, status) em 'dadosPrincipais'
  const entrega = await prisma.entregas.findUnique({
      where: { id: parseInt(id) }
  });
  const { itens, ...dadosPrincipais } = dados;

  // 2. Preparamos o objeto base que vai atualizar a tabela 'entregas'
  let dataParaAtualizar = { ...dadosPrincipais };

  // 3. Se a requisição incluir novos itens, preparamos a transação aninhada
  if (itens && Array.isArray(itens)) {
    dataParaAtualizar.itens_entrega = {
      deleteMany: {}, // Apaga todos os registros antigos DESTA entrega na tabela itens_entrega
      create: itens.map(item => ({ // Recria os novos itens recebidos no body
        variedade_id: item.variedade_id,
        quantidade: item.quantidade
      }))
    };
  }

  // 4. Salva no banco de dados
  const entregaAtualizada = await prisma.entregas.update({
    where: {
      id: parseInt(id) // Garante que o ID seja numérico
    },
    data: dataParaAtualizar
  });

  await recalcularStatusEntrega(entrega.encomenda_id);

  return entregaAtualizada;
};

const eliminarEntrega = async (id) => {
    // 1. Localiza a entrega antes de apagar para saber qual encomenda recalcular
    const entrega = await prisma.entregas.findUnique({
        where: { id: parseInt(id) }
    });

    if (!entrega) {
        throw new Error('Entrega não encontrada.');
    }

    // 2. Apaga o registro (o Prisma deleta os itens vinculados em cascata)
    const resultado = await prisma.entregas.delete({
        where: { id: parseInt(id) }
    });

    // 3. AUTOMAÇÃO: Recalcula. Se apagou uma entrega, a encomenda volta para "Parcial" ou "Pendente"
    await recalcularStatusEntrega(entrega.encomenda_id);

    return resultado;
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega
};