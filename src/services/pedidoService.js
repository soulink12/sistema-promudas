const prisma = require('../config/database');
const { recalcularStatusPedido } = require('./pagamentoService');
const { parseData, normalizarDatas } = require('../utils/parseData');
const formaPagamentoService = require('./formaPagamentoService');

// Campos de pagamento retornados ao montar um pedido completo (listar/buscar).
const PAGAMENTO_SELECT = {
    id: true,
    valor_pago: true,
    data_pagamento: true,
    forma_pagamento: true,
    parcelas: true,
    conta: true,
    nome_pagador: true,
    cpf_cnpj_pagador: true,
    status_nota: true,
    numero_nota: true,
    data_emissao_nota: true,
    escambo_quantidade: true,
    criado_em: true,
    cheques: {
        select: {
            id: true,
            numero: true,
            banco: true,
            agencia: true,
            conta_corrente: true,
            valor: true,
            bom_para: true,
            data_deposito: true,
            depositado: true,
        },
    },
};

// Include padrão de um pedido completo: cliente, itens (com nome do produto),
// pagamentos (PAGAMENTO_SELECT) e entregas com seus itens.
const PEDIDO_INCLUDE = {
    clientes: { select: { id: true, nome: true } },
    itens_pedido: {
        include: { produtos: { select: { nome: true } } }
    },
    pagamentos: {
        select: PAGAMENTO_SELECT,
        orderBy: { criado_em: 'asc' }
    },
    entregas: {
        include: { itens_entrega: true }
    }
};

// Próximo número sequencial dentro de uma temporada (MAX + 1). Robusto para a
// importação de dados (continua a partir do maior número já usado) e para
// reativar uma temporada anterior (não duplica). `client` pode ser o prisma ou
// um cliente de transação (tx).
const proximoNumeroTemporada = async (client, ano) => {
    const agg = await client.pedidos.aggregate({
        _max: { numero_temporada: true },
        where: { temporada_ano: ano },
    });
    return (agg._max.numero_temporada ?? 0) + 1;
};

// Quando um update troca a temporada do pedido, recomputa o numero_temporada
// (próximo da nova temporada). Muta `campos` ajustando temporada_ano/numero_temporada.
const aplicarTrocaTemporada = async (client, id, campos) => {
    if (campos.temporada_ano === undefined) return;

    const atual = await client.pedidos.findUnique({
        where: { id: parseInt(id) },
        select: { temporada_ano: true },
    });

    const novoAno = campos.temporada_ano === null ? null : parseInt(campos.temporada_ano);
    campos.temporada_ano = novoAno;

    if (novoAno === atual?.temporada_ano) return; // sem mudança de temporada
    campos.numero_temporada = novoAno === null
        ? null
        : await proximoNumeroTemporada(client, novoAno);
};

const criarPedido = async (dados) => {
    return await prisma.$transaction(async (tx) => {
        // O número de temporada vem da temporada ativa (configurada no Admin).
        // Sem temporada ativa, o pedido fica sem número (exibe '#id' como fallback).
        const temporada = await tx.temporadas.findFirst({ where: { ativo: true } });
        const temporada_ano = temporada?.ano ?? null;
        const numero_temporada = temporada
            ? await proximoNumeroTemporada(tx, temporada.ano)
            : null;

        return await tx.pedidos.create({
            data: {
                clientes: {
                    connect: { id: parseInt(dados.cliente_id) }
                },
                valor_total: dados.valor_total,
                ajuste: dados.ajuste ?? null,
                observacoes: dados.observacoes,
                // Na criação, a data do pedido é o momento atual (= criado_em).
                // Pode ser alterada depois na consulta (PUT /pedidos/:id).
                data_pedido: parseData(dados.data_pedido, 'data_pedido') ?? new Date(),
                status_geral: 'Ativa',
                ativo: true,
                temporada_ano,
                numero_temporada,

                itens_pedido: {
                    create: dados.itens.map(item => ({
                        produto_id: parseInt(item.produto_id),
                        quantidade: parseInt(item.quantidade),
                        valor_unitario: item.valor_unitario
                    }))
                }
            },
            include: {
                itens_pedido: true
            }
        });
    });
};

// Status da nota fiscal do pedido, agregado a partir dos pagamentos reais
// (crediário/"a receber" não conta — ainda não há nota). Mesma regra do front
// (lista_pedidos.dart). Prioridade: Rejeitada > Processando > Emitida (todas) >
// Parcial (algumas) > Pendente. Recebe os pagamentos já com a flag pagamento_posterior.
const statusNotaPedido = (pagamentos) => {
    const reais = pagamentos.filter(p => p.pagamento_posterior !== true);
    if (reais.length === 0) return 'Pendente';

    const statuses = reais.map(p => p.status_nota ?? 'Pendente');
    if (statuses.includes('Rejeitada')) return 'Rejeitada';
    if (statuses.includes('Processando')) return 'Processando';

    const emitidas = statuses.filter(s => s === 'Emitida').length;
    if (emitidas === 0) return 'Pendente';
    if (emitidas === statuses.length) return 'Emitida';
    return 'Parcial';
};

const listarPedidos = async (filtros = {}) => {
    const where = { ativo: true };
    if (filtros.cliente) {
        where.clientes = { nome: { contains: filtros.cliente } };
    }
    // Filtra por status de entrega (ex.: 'Pendente,Parcial') quando informado
    if (filtros.statusEntrega) {
        where.status_entrega = { in: filtros.statusEntrega.split(',') };
    }
    // Filtra por status de pagamento (ex.: 'Pendente,Parcial') quando informado
    if (filtros.statusPagamento) {
        where.status_pagamento = { in: filtros.statusPagamento.split(',') };
    }
    // Intervalo de datas (criado_em) — obrigatório no front (padrão: última semana).
    if (filtros.de || filtros.ate) {
        where.criado_em = {
            ...(filtros.de && { gte: new Date(filtros.de) }),
            ...(filtros.ate && { lte: new Date(filtros.ate) }),
        };
    }

    const [pedidos, formasPosteriores] = await Promise.all([
        prisma.pedidos.findMany({
            where,
            orderBy: { criado_em: 'desc' },
            include: PEDIDO_INCLUDE
        }),
        formaPagamentoService.listarPosteriores()
    ]);

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));

    // Adiciona flag pagamento_posterior em cada pagamento
    const comFlag = pedidos.map(pedido => ({
        ...pedido,
        pagamentos: pedido.pagamentos.map(pag => ({
            ...pag,
            pagamento_posterior: nomesPosteriores.has(pag.forma_pagamento)
        }))
    }));

    // Filtra por status de nota (agregado dos pagamentos reais) — feito em memória,
    // pois a nota não é uma coluna do pedido.
    if (filtros.statusNota) {
        const alvo = new Set(filtros.statusNota.split(','));
        return comFlag.filter(p => alvo.has(statusNotaPedido(p.pagamentos)));
    }
    return comFlag;
};

const atualizarPedido = async (id, dados) => {
    const { itens, ...camposBrutos } = dados;
    const camposPedido = normalizarDatas(camposBrutos, ['data_pedido']);

    if (!itens) {
        return await prisma.$transaction(async (tx) => {
            await aplicarTrocaTemporada(tx, id, camposPedido);
            return await tx.pedidos.update({
                where: { id: parseInt(id) },
                data: camposPedido,
            });
        });
    }

    // Caso o update também troque a temporada (raro nesta ramificação), recomputa o número.
    await aplicarTrocaTemporada(prisma, id, camposPedido);

    const [pedidoAtual, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(id) },
            select: {
                ajuste: true,
                cliente_id: true,
                pagamentos: { select: { valor_pago: true, forma_pagamento: true } },
            },
        }),
        formaPagamentoService.listarPosteriores(),
    ]);

    const ajuste = camposPedido.ajuste !== undefined
        ? Number(camposPedido.ajuste ?? 0)
        : Number(pedidoAtual?.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const totalPagoReal = (pedidoAtual?.pagamentos ?? [])
        .filter(p => !nomesPosteriores.has(p.forma_pagamento))
        .reduce((s, p) => s + parseFloat(p.valor_pago), 0);

    const novoTotal = subtotal + ajuste;
    const creditoGerado = Math.max(0, totalPagoReal - novoTotal);

    if (creditoGerado > 0.01 && pedidoAtual?.cliente_id) {
        await prisma.clientes.update({
            where: { id: pedidoAtual.cliente_id },
            data: { saldo_credito: { increment: creditoGerado } },
        });
    }

    await prisma.itens_pedido.deleteMany({ where: { pedido_id: parseInt(id) } });

    const resultado = await prisma.pedidos.update({
        where: { id: parseInt(id) },
        data: {
            ...camposPedido,
            valor_total: novoTotal,
            itens_pedido: {
                create: itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: parseFloat(item.valor_unitario),
                })),
            },
        },
        include: {
            itens_pedido: {
                include: { produtos: { select: { nome: true } } },
            },
        },
    });

    await recalcularStatusPedido(id);

    return { ...resultado, creditoGerado };
};

const buscarPedido = async (id) => {
    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(id), ativo: true },
            include: PEDIDO_INCLUDE
        }),
        formaPagamentoService.listarPosteriores()
    ]);

    if (!pedido) return null;

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    return {
        ...pedido,
        pagamentos: pedido.pagamentos.map(pag => ({
            ...pag,
            pagamento_posterior: nomesPosteriores.has(pag.forma_pagamento)
        }))
    };
};

const eliminarPedido = async (id) => {
    return await prisma.pedidos.update({
        where: { id: parseInt(id) },
        data: { ativo: false }
    });
};

module.exports = {
    criarPedido,
    listarPedidos,
    buscarPedido,
    atualizarPedido,
    eliminarPedido
};
