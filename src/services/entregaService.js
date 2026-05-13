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
  const entregaId = parseInt(id);

  // 1. Busca a entrega original para pegar a encomenda vinculada
  const entregaOriginal = await prisma.entregas.findUnique({
    where: { id: entregaId },
    select: { encomenda_id: true }
  });

  if (!entregaOriginal) {
    throw new Error("Entrega não encontrada.");
  }

  const { itens, ...dadosPrincipais } = dados;

  // 2. Se a requisição incluir itens, fazemos a validação de Saldo de Mudas
  if (itens && Array.isArray(itens)) {
    // A. Busca o que o cliente comprou na encomenda
    const encomenda = await prisma.encomendas.findUnique({
      where: { id: entregaOriginal.encomenda_id },
      include: { itens_encomenda: true }
    });

    // B. Busca as OUTRAS entregas já feitas para esta encomenda (ignorando a atual)
    const outrasEntregas = await prisma.entregas.findMany({
      where: {
        encomenda_id: entregaOriginal.encomenda_id,
        id: { not: entregaId } // <- O Segredo: Ignora a entrega que estamos a editar
      },
      include: { itens_entrega: true }
    });

    // C. Calcula o total já entregue (somente pelas OUTRAS entregas)
    const jaEntregue = {};
    outrasEntregas.forEach(ent => {
      ent.itens_entrega.forEach(item => {
        jaEntregue[item.variedade_id] = (jaEntregue[item.variedade_id] || 0) + item.quantidade;
      });
    });

    // D. Valida cada novo item que queremos guardar nesta entrega
    for (const novoItem of itens) {
      // Quanto ele comprou no total desta variedade?
      const itemComprado = encomenda.itens_encomenda.find(i => i.variedade_id === novoItem.variedade_id);
      const totalComprado = itemComprado ? itemComprado.quantidade : 0;

      if (totalComprado === 0) {
        throw new Error(`A variedade ID ${novoItem.variedade_id} não faz parte desta encomenda.`);
      }

      // Qual o saldo restante (sem contar a entrega atual)?
      const totalOutrasEntregas = jaEntregue[novoItem.variedade_id] || 0;
      const saldoDisponivel = totalComprado - totalOutrasEntregas;

      // Se a quantidade enviada for maior que o saldo, bloqueia a edição
      if (novoItem.quantidade > saldoDisponivel) {
        throw new Error(`Atenção: Saldo insuficiente para a variedade ID ${novoItem.variedade_id}. O valor máximo dessa entrega deve ser ${saldoDisponivel}.`);
      }
    }
  }

  // 3. Preparamos o objeto base que vai atualizar a tabela 'entregas'
  let dataParaAtualizar = { ...dadosPrincipais };

  // 4. Se passou na validação, prepara a transação aninhada do Prisma
  if (itens && Array.isArray(itens)) {
    dataParaAtualizar.itens_entrega = {
      deleteMany: {}, // Apaga todos os registros antigos DESTA entrega
      create: itens.map(item => ({ // Recria os novos itens recebidos no body
        variedade_id: item.variedade_id,
        quantidade: item.quantidade
      }))
    };
  }

  // 5. Salva no banco de dados
  const entregaAtualizada = await prisma.entregas.update({
    where: {
      id: entregaId
    },
    data: dataParaAtualizar
  });

  // 6. Recalcula o status geral da entrega para a Encomenda
  await recalcularStatusEntrega(entregaOriginal.encomenda_id);

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