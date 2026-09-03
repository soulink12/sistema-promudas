const prisma = require('../config/database');
const { normalizarDatas } = require('../utils/parseData');
const pdfService = require('./pdfService');
const emailService = require('./emailService');
const pedidoService = require('./pedidoService');
const { formatarNumeroOrcamento } = require('../utils/numeroOrcamento');
const BusinessError = require('../utils/BusinessError');

const ORCAMENTO_INCLUDE = {
    clientes: { select: { id: true, nome: true } },
    itens_orcamento: {
        include: { produtos: { select: { nome: true } } }
    }
};

const criarOrcamento = async (dados) => {
    return await prisma.orcamentos.create({
        data: {
            clientes: {
                connect: { id: parseInt(dados.cliente_id) }
            },
            valor_total: dados.valor_total,
            ajuste: dados.ajuste ?? null,
            observacoes: dados.observacoes,
            data_orcamento: new Date(),
            status: 'Pendente',
            ativo: true,

            itens_orcamento: {
                create: dados.itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: item.valor_unitario
                }))
            }
        },
        include: {
            itens_orcamento: true
        }
    });
};

const listarOrcamentos = async (filtros = {}) => {
    const where = { ativo: true };
    if (filtros.cliente) {
        where.clientes = { nome: { contains: filtros.cliente } };
    }
    if (filtros.status) {
        where.status = { in: filtros.status.split(',') };
    }
    if (filtros.de || filtros.ate) {
        where.criado_em = {
            ...(filtros.de && { gte: new Date(filtros.de) }),
            ...(filtros.ate && { lte: new Date(filtros.ate) }),
        };
    }
    if (filtros.numero) {
        // Orçamento usa numeração própria simples — só o formato "#id" (ou "id" puro).
        const bruto = filtros.numero.trim().replace(/^#/, '');
        where.id = /^\d+$/.test(bruto) ? parseInt(bruto) : -1;
    }

    return await prisma.orcamentos.findMany({
        where,
        orderBy: { criado_em: 'desc' },
        include: ORCAMENTO_INCLUDE
    });
};

const buscarOrcamento = async (id) => {
    return await prisma.orcamentos.findUnique({
        where: { id: parseInt(id), ativo: true },
        include: ORCAMENTO_INCLUDE
    });
};

// Edita um orçamento pendente (cliente, itens, ajuste, observações). Recalcula
// o valor_total a partir dos itens+ajuste, como a edição de pedido faz.
// Bloqueia edição de orçamento já aprovado/rejeitado.
const atualizarOrcamento = async (id, dados) => {
    const orcamentoAtual = await prisma.orcamentos.findUnique({
        where: { id: parseInt(id) },
        select: { status: true, ajuste: true },
    });
    if (!orcamentoAtual) {
        throw new BusinessError('Orçamento não encontrado.', 404);
    }
    if (orcamentoAtual.status !== 'Pendente') {
        throw new BusinessError('Este orçamento já foi aprovado ou recusado e não pode mais ser alterado.');
    }

    const { itens, ...camposBrutos } = dados;
    const camposOrcamento = normalizarDatas(camposBrutos, ['data_orcamento']);

    if (!itens) {
        return await prisma.orcamentos.update({
            where: { id: parseInt(id) },
            data: camposOrcamento,
        });
    }

    const ajuste = camposOrcamento.ajuste !== undefined
        ? Number(camposOrcamento.ajuste ?? 0)
        : Number(orcamentoAtual.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    await prisma.itens_orcamento.deleteMany({ where: { orcamento_id: parseInt(id) } });

    return await prisma.orcamentos.update({
        where: { id: parseInt(id) },
        data: {
            ...camposOrcamento,
            valor_total: subtotal + ajuste,
            itens_orcamento: {
                create: itens.map(item => ({
                    produto_id: parseInt(item.produto_id),
                    quantidade: parseInt(item.quantidade),
                    valor_unitario: parseFloat(item.valor_unitario),
                })),
            },
        },
        include: {
            itens_orcamento: {
                include: { produtos: { select: { nome: true } } },
            },
        },
    });
};

const eliminarOrcamento = async (id) => {
    return await prisma.orcamentos.update({
        where: { id: parseInt(id) },
        data: { ativo: false }
    });
};

// Aprova o orçamento: cria um Pedido de verdade com os mesmos dados (cliente,
// itens, ajuste, observações) — nasce sem pagamento/entrega, como um pedido
// novo qualquer — e marca o orçamento como Aprovado, vinculado ao pedido criado.
const aprovarOrcamento = async (id) => {
    return await prisma.$transaction(async (tx) => {
        const orcamento = await tx.orcamentos.findUnique({
            where: { id: parseInt(id) },
            include: { itens_orcamento: true },
        });
        if (!orcamento) {
            throw new BusinessError('Orçamento não encontrado.', 404);
        }
        if (orcamento.status !== 'Pendente') {
            throw new BusinessError('Este orçamento já foi aprovado ou recusado.');
        }

        const temporada = await tx.temporadas.findFirst({ where: { ativo: true } });
        const temporada_ano = temporada?.ano ?? null;
        const numero_temporada = temporada
            ? await pedidoService.proximoNumeroTemporada(tx, temporada.ano)
            : null;

        const pedido = await tx.pedidos.create({
            data: {
                clientes: { connect: { id: orcamento.cliente_id } },
                valor_total: orcamento.valor_total,
                ajuste: orcamento.ajuste,
                observacoes: orcamento.observacoes,
                data_pedido: new Date(),
                status_geral: 'Ativa',
                ativo: true,
                temporada_ano,
                numero_temporada,
                itens_pedido: {
                    create: orcamento.itens_orcamento.map(item => ({
                        produto_id: item.produto_id,
                        quantidade: item.quantidade,
                        valor_unitario: item.valor_unitario,
                    })),
                },
            },
        });

        return await tx.orcamentos.update({
            where: { id: parseInt(id) },
            data: { status: 'Aprovado', pedido_id: pedido.id },
            include: ORCAMENTO_INCLUDE,
        });
    });
};

const recusarOrcamento = async (id) => {
    const orcamento = await prisma.orcamentos.findUnique({
        where: { id: parseInt(id) },
        select: { status: true },
    });
    if (!orcamento) {
        throw new BusinessError('Orçamento não encontrado.', 404);
    }
    if (orcamento.status !== 'Pendente') {
        throw new BusinessError('Este orçamento já foi aprovado ou recusado.');
    }
    return await prisma.orcamentos.update({
        where: { id: parseInt(id) },
        data: { status: 'Rejeitado' },
    });
};

const enviarOrcamentoPorEmail = async (id) => {
    const orcamento = await prisma.orcamentos.findUnique({
        where: { id: parseInt(id) },
        select: {
            id: true,
            clientes: { select: { nome: true, email: true } },
        },
    });
    if (!orcamento) {
        throw new BusinessError('Orçamento não encontrado.', 404);
    }
    if (!orcamento.clientes?.email) {
        throw new BusinessError('Este cliente não tem e-mail cadastrado.');
    }

    const { buffer, nomeArquivo } = await pdfService.gerarOrcamentoPDF(id);
    await emailService.enviarPdfPorEmail({
        destinatario: orcamento.clientes.email,
        assunto: `Orçamento ${formatarNumeroOrcamento(orcamento)} — Viveiro Promudas`,
        corpo: `Olá, ${orcamento.clientes.nome}!\n\nSegue em anexo o seu orçamento na Viveiro Promudas.\n\nQualquer dúvida, estamos à disposição.`,
        anexoBuffer: buffer,
        nomeArquivo,
    });
};

module.exports = {
    criarOrcamento,
    listarOrcamentos,
    buscarOrcamento,
    atualizarOrcamento,
    eliminarOrcamento,
    aprovarOrcamento,
    recusarOrcamento,
    enviarOrcamentoPorEmail
};
