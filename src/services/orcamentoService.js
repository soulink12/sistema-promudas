const prisma = require('../config/database');
const { normalizarDatas } = require('../utils/parseData');
const pdfService = require('./pdfService');
const emailService = require('./emailService');
const pedidoService = require('./pedidoService');
const { formatarNumeroOrcamento } = require('../utils/numeroOrcamento');
const { retryColisao } = require('../utils/retryColisao');
const BusinessError = require('../utils/BusinessError');

const ORCAMENTO_INCLUDE = {
    clientes: { select: { id: true, nome: true, email: true } },
    itens_orcamento: {
        include: { produtos: { select: { nome: true } } }
    }
};

const criarOrcamento = async (dados) => {
    // valor_total é sempre recalculado a partir dos itens (não confia no
    // cliente), mesma lógica de pedidoService.criarPedidoTx.
    const subtotal = dados.itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );
    const ajuste = Number(dados.ajuste ?? 0);

    return await prisma.orcamentos.create({
        data: {
            clientes: {
                connect: { id: parseInt(dados.cliente_id) }
            },
            valor_total: subtotal + ajuste,
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
        orderBy: [{ data_orcamento: 'desc' }, { criado_em: 'desc' }],
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
            include: ORCAMENTO_INCLUDE,
        });
    }

    const ajuste = camposOrcamento.ajuste !== undefined
        ? Number(camposOrcamento.ajuste ?? 0)
        : Number(orcamentoAtual.ajuste ?? 0);

    const subtotal = itens.reduce(
        (s, item) => s + parseFloat(item.valor_unitario) * parseInt(item.quantidade),
        0
    );

    return await prisma.$transaction(async (tx) => {
        await tx.itens_orcamento.deleteMany({ where: { orcamento_id: parseInt(id) } });

        return await tx.orcamentos.update({
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
            include: ORCAMENTO_INCLUDE,
        });
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
// Mesma corrida de numero_temporada de pedidoService.criarPedido (a aprovação
// cria um pedido de verdade via criarPedidoTx) — retryColisao tenta de novo
// em vez de propagar um 500 por uma colisão que se resolve sozinha na repetição.
const aprovarOrcamento = async (id) => {
    return await retryColisao(() => prisma.$transaction(async (tx) => {
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

        const pedido = await pedidoService.criarPedidoTx(tx, {
            cliente_id: orcamento.cliente_id,
            valor_total: orcamento.valor_total,
            ajuste: orcamento.ajuste,
            observacoes: orcamento.observacoes,
            itens: orcamento.itens_orcamento.map(item => ({
                produto_id: item.produto_id,
                quantidade: item.quantidade,
                valor_unitario: item.valor_unitario,
            })),
        });

        return await tx.orcamentos.update({
            where: { id: parseInt(id) },
            data: { status: 'Aprovado', pedido_id: pedido.id },
            include: ORCAMENTO_INCLUDE,
        });
    }));
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

// Dispara os e-mails de um evento de orçamento — best-effort, veja
// emailService.notificarEvento. `evento` é uma chave de emailService.EVENTOS.
const notificarOrcamentoPorEmail = (id, evento) => emailService.notificarEvento({
    id,
    evento,
    gerarPDF: pdfService.gerarOrcamentoPDF,
    formatarNumero: formatarNumeroOrcamento,
});

const enviarOrcamentoPorEmail = (id) => emailService.enviarDocumentoPorEmail({
    id,
    evento: 'orcamentoManual',
    gerarPDF: pdfService.gerarOrcamentoPDF,
    formatarNumero: formatarNumeroOrcamento,
});

module.exports = {
    criarOrcamento,
    listarOrcamentos,
    buscarOrcamento,
    atualizarOrcamento,
    eliminarOrcamento,
    aprovarOrcamento,
    recusarOrcamento,
    enviarOrcamentoPorEmail,
    notificarOrcamentoPorEmail
};
