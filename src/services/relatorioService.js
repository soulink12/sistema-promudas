const PDFDocument = require('pdfkit');
const prisma = require('../config/database');

const moeda = (v) => `R$ ${parseFloat(v || 0).toFixed(2).replace('.', ',')}`;

const formatarData = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    return dt.toLocaleDateString('pt-BR') + '  ' + dt.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
};

const formatarDataCurta = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    return dt.toLocaleDateString('pt-BR');
};

const linhaHorizontal = (doc, cor = '#cccccc') => {
    doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor(cor).lineWidth(0.5).stroke();
    doc.strokeColor('black').lineWidth(1);
};

const _montarWhere = ({ de, ate, forma }) => {
    // TODO: quando data_pagamento se tornar obrigatório, remover o OR e filtrar só por data_pagamento
    const whereData = (de || ate) ? {
        OR: [
            {
                data_pagamento: {
                    ...(de && { gte: new Date(de) }),
                    ...(ate && { lte: new Date(ate) }),
                }
            },
            {
                data_pagamento: null,
                criado_em: {
                    ...(de && { gte: new Date(de) }),
                    ...(ate && { lte: new Date(ate) }),
                }
            }
        ]
    } : {};

    return {
        ...whereData,
        ...(forma ? { forma_pagamento: forma } : {})
    };
};

const relatorioPagamentos = async ({ de, ate, forma }) => {
    const where = _montarWhere({ de, ate, forma });

    const grupos = await prisma.pagamentos.groupBy({
        by: ['forma_pagamento'],
        where,
        _sum: { valor_pago: true },
        _count: { id: true },
        orderBy: { _sum: { valor_pago: 'desc' } }
    });

    const resultado = grupos.map(g => ({
        forma_pagamento: g.forma_pagamento ?? '(não informado)',
        total: parseFloat(g._sum.valor_pago ?? 0),
        quantidade: g._count.id,
    }));

    const totalGeral = resultado.reduce((soma, r) => soma + r.total, 0);

    return { resultado, totalGeral };
};

const gerarRelatorioPDF = async ({ de, ate, forma }) => {
    const where = _montarWhere({ de, ate, forma });

    const [grupos, pagamentos] = await Promise.all([
        prisma.pagamentos.groupBy({
            by: ['forma_pagamento'],
            where,
            _sum: { valor_pago: true },
            _count: { id: true },
            orderBy: { _sum: { valor_pago: 'desc' } }
        }),
        prisma.pagamentos.findMany({
            where,
            include: {
                pedidos: {
                    select: {
                        id: true,
                        clientes: { select: { nome: true } }
                    }
                }
            },
            orderBy: [
                { forma_pagamento: 'asc' },
                { data_pagamento: 'asc' },
                { criado_em: 'asc' }
            ]
        })
    ]);

    const resumo = grupos.map(g => ({
        forma_pagamento: g.forma_pagamento ?? '(não informado)',
        total: parseFloat(g._sum.valor_pago ?? 0),
        quantidade: g._count.id,
    }));
    const totalGeral = resumo.reduce((s, r) => s + r.total, 0);

    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // ── CABEÇALHO ──────────────────────────────────────────────────────
        doc.font('Helvetica-Bold').fontSize(20).fillColor('#1b5e20')
            .text('Viveiro Promudas', { align: 'center' });
        doc.font('Helvetica').fontSize(10).fillColor('#555555')
            .text('Relatório de Pagamentos', { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.5);

        // Período e filtros aplicados
        const periodoParts = [];
        if (de) periodoParts.push(`De: ${formatarDataCurta(de)}`);
        if (ate) periodoParts.push(`Até: ${formatarDataCurta(ate)}`);
        if (!de && !ate) periodoParts.push('Todo o período');
        if (forma) periodoParts.push(`Forma: ${forma}`);
        doc.font('Helvetica').fontSize(9).fillColor('#777777')
            .text(periodoParts.join('   '), { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.8);

        // Limite inferior utilizável da página
        const paginaFundo = doc.page.height - doc.page.margins.bottom;

        // Renderiza o cabeçalho da tabela de resumo (reutilizado após quebra de página)
        const cabecalhoResumo = () => {
            doc.font('Helvetica-Bold').fontSize(9).fillColor('#555555');
            const y = doc.y;
            doc.text('Forma de Pagamento', 50, y, { width: 250, lineBreak: false });
            doc.text('Qtd', 310, y, { width: 60, align: 'center', lineBreak: false });
            doc.text('Total', 460, y, { width: 85, align: 'right' });
            doc.fillColor('black');
            doc.moveDown(0.3);
            doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
            doc.strokeColor('black').lineWidth(1);
            doc.moveDown(0.3);
        };

        // Renderiza o cabeçalho da tabela de detalhes (reutilizado após quebra de página)
        const cabecalhoDetalhes = () => {
            doc.font('Helvetica-Bold').fontSize(8).fillColor('#555555');
            const y = doc.y;
            doc.text('Data', 50, y, { width: 88, lineBreak: false });
            doc.text('Forma', 143, y, { width: 100, lineBreak: false });
            doc.text('Ped.', 248, y, { width: 38, align: 'center', lineBreak: false });
            doc.text('Cliente', 291, y, { width: 164, lineBreak: false });
            doc.text('Valor', 460, y, { width: 85, align: 'right' });
            doc.fillColor('black');
            doc.moveDown(0.3);
            doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
            doc.strokeColor('black').lineWidth(1);
            doc.moveDown(0.3);
        };

        // ── RESUMO POR FORMA ───────────────────────────────────────────────
        linhaHorizontal(doc);
        doc.moveDown(0.5);
        doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20')
            .text('RESUMO POR FORMA DE PAGAMENTO');
        doc.fillColor('black');
        doc.moveDown(0.4);
        cabecalhoResumo();

        let idxResumo = 0;
        resumo.forEach((r) => {
            // Quebra de página se não há espaço para mais uma linha (≈ 18pt)
            if (doc.y + 18 > paginaFundo) {
                doc.addPage();
                cabecalhoResumo();
                idxResumo = 0;
            }
            const y = doc.y;
            if (idxResumo % 2 === 0) doc.rect(50, y - 2, 495, 16).fill('#f9f9f9');
            doc.font('Helvetica').fontSize(9).fillColor('black');
            doc.text(r.forma_pagamento, 50, y, { width: 250, lineBreak: false });
            doc.text(String(r.quantidade), 310, y, { width: 60, align: 'center', lineBreak: false });
            doc.text(moeda(r.total), 460, y, { width: 85, align: 'right' });
            doc.moveDown(0.45);
            idxResumo++;
        });

        doc.moveDown(0.4);

        // Total geral
        doc.moveTo(310, doc.y).lineTo(545, doc.y).strokeColor('#aaaaaa').lineWidth(0.5).stroke();
        doc.strokeColor('black').lineWidth(1);
        doc.moveDown(0.3);
        const yTotalGeral = doc.y;
        doc.font('Helvetica-Bold').fontSize(11).fillColor('#555555')
            .text('TOTAL GERAL', 310, yTotalGeral, { lineBreak: false });
        doc.fillColor('#1b5e20').text(moeda(totalGeral), 460, yTotalGeral, { width: 85, align: 'right' });
        doc.fillColor('black');
        doc.moveDown(1.2);

        // ── DETALHES DOS PAGAMENTOS ────────────────────────────────────────
        linhaHorizontal(doc);
        doc.moveDown(0.5);
        doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20')
            .text('DETALHES DOS PAGAMENTOS');
        doc.fillColor('black');
        doc.moveDown(0.4);
        cabecalhoDetalhes();

        if (pagamentos.length === 0) {
            doc.font('Helvetica').fontSize(9).fillColor('#888888')
                .text('Nenhum pagamento encontrado para os filtros aplicados.');
            doc.fillColor('black');
        } else {
            let idxDet = 0;
            pagamentos.forEach((pag) => {
                // Quebra de página se não há espaço para mais uma linha (≈ 14pt)
                if (doc.y + 14 > paginaFundo) {
                    doc.addPage();
                    cabecalhoDetalhes();
                    idxDet = 0;
                }
                const dataEfetiva = pag.data_pagamento || pag.criado_em;
                const pedidoId = pag.pedidos?.id ? `#${pag.pedidos.id}` : '—';
                const cliente = pag.pedidos?.clientes?.nome ?? '—';
                const formaPag = pag.forma_pagamento ?? '(não informado)';

                const y = doc.y;
                if (idxDet % 2 === 0) doc.rect(50, y - 2, 495, 15).fill('#f9f9f9');
                doc.font('Helvetica').fontSize(8).fillColor('black');
                doc.text(formatarData(dataEfetiva), 50, y, { width: 88, lineBreak: false });
                doc.text(formaPag, 143, y, { width: 100, lineBreak: false });
                doc.text(pedidoId, 248, y, { width: 38, align: 'center', lineBreak: false });
                doc.text(cliente, 291, y, { width: 164, lineBreak: false });
                doc.text(moeda(pag.valor_pago), 460, y, { width: 85, align: 'right' });
                doc.moveDown(0.4);
                idxDet++;
            });
        }

        // ── RODAPÉ ─────────────────────────────────────────────────────────
        doc.moveDown(2);
        linhaHorizontal(doc);
        doc.moveDown(0.4);
        doc.font('Helvetica').fontSize(8).fillColor('#aaaaaa')
            .text(`Viveiro Promudas — documento gerado em ${formatarData(new Date())}`, { align: 'center' });

        doc.end();
    });
};

module.exports = { relatorioPagamentos, gerarRelatorioPDF };
