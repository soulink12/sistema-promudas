const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');

const listarFormasPagamento = async () => {
    return await prisma.formas_pagamento.findMany({
        orderBy: { nome: 'asc' },
        select: { id: true, nome: true, ativo: true, pagamento_posterior: true, conta_posterior: true, deposito_posterior: true, parcelado_em_ate: true, escambo: true, valor_kg_escambo: true }
    });
};

// Cria uma forma de pagamento. Recebe um objeto para acomodar os vários flags
// (crediário, conta posterior, cheque, escambo) sem uma lista posicional gigante.
const criarForma = async ({
    nome,
    pagamento_posterior = false,
    conta_posterior = false,
    deposito_posterior = false,
    parcelado_em_ate = 1,
    escambo = false,
    valor_kg_escambo = null,
}) => {
    return await prisma.formas_pagamento.create({
        data: {
            nome,
            pagamento_posterior,
            conta_posterior,
            deposito_posterior,
            parcelado_em_ate,
            escambo,
            valor_kg_escambo,
        }
    });
};

const atualizarForma = async (id, dados) => {
    const existe = await prisma.formas_pagamento.findUnique({ where: { id } });
    if (!existe) throw new BusinessError('Forma de pagamento não encontrada.', 404);

    // `pagamentos.forma_pagamento` guarda o NOME da forma, não uma chave
    // estrangeira, e toda a lógica financeira (crediário e cheque em
    // recalcularStatusPedido) casa por esse nome. Renomear uma forma já usada
    // reclassificaria silenciosamente todos os pagamentos antigos — crediário
    // viraria dinheiro recebido e o pedido apareceria como Pago sem ter sido.
    // Os demais campos continuam editáveis normalmente.
    const renomeando = dados.nome !== undefined && dados.nome !== existe.nome;
    if (renomeando) {
        const emUso = await prisma.pagamentos.count({
            where: { forma_pagamento: existe.nome },
        });
        if (emUso > 0) {
            throw new BusinessError(
                `Esta forma de pagamento já foi usada em ${emUso} ${emUso === 1 ? 'pagamento' : 'pagamentos'} e não pode ser renomeada. ` +
                'Para parar de usá-la, desative-a e crie uma nova com o nome desejado.'
            );
        }
    }

    return await prisma.formas_pagamento.update({
        where: { id },
        data: dados
    });
};

const deletarForma = async (id) => {
    const existe = await prisma.formas_pagamento.findUnique({ where: { id } });
    if (!existe) throw new BusinessError('Forma de pagamento não encontrada.', 404);
    await prisma.formas_pagamento.update({ where: { id }, data: { ativo: false } });
};

// Lista as formas marcadas como pagamento posterior (crediário), em ordem
// alfabética — mesma ordem de listarFormasPagamento/GET /formas-pagamento.
// Usado para excluir esses pagamentos do cálculo de valor efetivamente
// recebido — por isso NÃO filtra `ativo` no `where`: um pagamento antigo
// lançado com uma forma já desativada continua precisando ser reconhecido
// como crediário (mesmo raciocínio de `atualizarForma`, que bloqueia
// renomear forma em uso — desativar não pode reclassificar histórico).
// `ativo` vai no `select` pra quem precisa saber quais estão disponíveis pra
// uso NOVO (pagamentoService.cobrirValorTx, ao escolher automaticamente qual
// forma usar pra lançar um crediário) sem afetar a classificação acima.
// Aceita um client opcional (ex.: `tx` de uma transação já aberta) — default
// usa o client global.
const listarPosteriores = (client = prisma) =>
    client.formas_pagamento.findMany({
        where: { pagamento_posterior: true },
        select: { nome: true, ativo: true },
        orderBy: { nome: 'asc' }
    });

// Lista as formas de depósito posterior (cheque). Usado para tratar os cheques
// como recebidos só após o depósito no cálculo de status do pedido.
const listarDepositoPosterior = () =>
    prisma.formas_pagamento.findMany({
        where: { deposito_posterior: true },
        select: { nome: true }
    });

// Lista as formas de escambo (troca). Usado para excluir esses pagamentos da
// lista de "pagamentos sem conta" (escambo não é dinheiro, não tem conta).
const listarEscambo = () =>
    prisma.formas_pagamento.findMany({
        where: { escambo: true },
        select: { nome: true }
    });

module.exports = { listarFormasPagamento, criarForma, atualizarForma, deletarForma, listarPosteriores, listarDepositoPosterior, listarEscambo };
