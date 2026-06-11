const PDFDocument = require('pdfkit');
const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');

const moeda = (v) => `R$ ${parseFloat(v || 0).toFixed(2).replace('.', ',')}`;

const formatarData = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    const dia = String(dt.getDate()).padStart(2, '0');
    const mes = String(dt.getMonth() + 1).padStart(2, '0');
    const hora = String(dt.getHours()).padStart(2, '0');
    const min = String(dt.getMinutes()).padStart(2, '0');
    return `${dia}/${mes}/${dt.getFullYear()}  ${hora}:${min}`;
};

// Desenha uma linha horizontal cinza
const linha = (doc) => {
    doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#cccccc').lineWidth(0.5).stroke();
    doc.strokeColor('black').lineWidth(1);
};

// Desenha uma linha de tabela com múltiplas colunas
const linhaTabela = (doc, y, colunas) => {
    colunas.forEach((col, i) => {
        const opts = { width: col.largura };
        if (col.alinhamento) opts.align = col.alinhamento;
        if (i < colunas.length - 1) opts.lineBreak = false;
        doc.text(col.texto, col.x, y, opts);
    });
};

const gerarPedidoPDF = async (pedidoId) => {
    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(pedidoId) },
            include: {
                clientes: true,
                itens_pedido: {
                    include: { produtos: { select: { nome: true } } }
                },
                pagamentos: {
                    orderBy: { criado_em: 'asc' }
                }
            }
        }),
        prisma.formas_pagamento.findMany({
            where: { pagamento_posterior: true },
            select: { nome: true }
        })
    ]);

    if (!pedido) {
        throw new BusinessError('Pedido não encontrado.', 404);
    }

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const pagamentosReais = pedido.pagamentos.filter(p => !nomesPosteriores.has(p.forma_pagamento));
    const saldoCredito = pedido.pagamentos
        .filter(p => nomesPosteriores.has(p.forma_pagamento))
        .reduce((s, p) => s + parseFloat(p.valor_pago), 0);

    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // ── CABEÇALHO ──────────────────────────────────────────────────────────

        doc.font('Helvetica-Bold').fontSize(20).fillColor('#1b5e20')
            .text('Viveiro Promudas', { align: 'center' });
        doc.font('Helvetica').fontSize(10).fillColor('#555555')
            .text('Recibo de Pedido', { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.8);

        linha(doc);
        doc.moveDown(0.5);

        // Número e data
        const dataPedido = formatarData(pedido.criado_em);
        doc.font('Helvetica-Bold').fontSize(14).text(`PEDIDO #${pedido.id}`, 50, doc.y, { continued: true });
        doc.font('Helvetica').fontSize(10).fillColor('#555555')
            .text(dataPedido, { align: 'right' });
        doc.fillColor('black');
        doc.moveDown(0.4);

        // Status
        const statusCor = pedido.status_pagamento === 'Pago'
            ? '#1b5e20'
            : pedido.status_pagamento === 'Parcial'
                ? '#e65100'
                : '#555555';
        doc.font('Helvetica').fontSize(10).text('Status: ', { continued: true });
        doc.font('Helvetica-Bold').fillColor(statusCor).text(pedido.status_pagamento);
        doc.fillColor('black');
        doc.moveDown(0.8);

        // ── CLIENTE ─────────────────────────────────────────────────────────────

        linha(doc);
        doc.moveDown(0.5);
        doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20').text('CLIENTE');
        doc.fillColor('black');
        doc.moveDown(0.2);
        doc.font('Helvetica-Bold').fontSize(11).text(pedido.clientes.nome);

        const c = pedido.clientes;
        doc.font('Helvetica').fontSize(9).fillColor('#555555');

        if (c.cpf_cnpj) doc.text(`CPF/CNPJ: ${c.cpf_cnpj}`);
        if (c.telefone_1) doc.text(`Telefone: ${c.telefone_1}`);

        // Endereço — monta apenas com os campos preenchidos
        if (c.logradouro) {
            const linha1 = [c.logradouro, c.numero].filter(Boolean).join(', ');
            const linha2Parts = [c.bairro, c.cidade && c.estado ? `${c.cidade}/${c.estado}` : (c.cidade || c.estado), c.cep].filter(Boolean);
            doc.text(linha1);
            if (linha2Parts.length > 0) doc.text(linha2Parts.join(' — '));
        }

        doc.fillColor('black');
        doc.moveDown(0.8);

        // ── ITENS ───────────────────────────────────────────────────────────────

        linha(doc);
        doc.moveDown(0.5);
        doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20').text('ITENS DO PEDIDO');
        doc.fillColor('black');
        doc.moveDown(0.4);

        // Cabeçalho da tabela de itens
        const colItens = [
            { x: 50, largura: 250, texto: 'Produto' },
            { x: 310, largura: 45, texto: 'Qtd', alinhamento: 'center' },
            { x: 365, largura: 85, texto: 'Preço Unit.', alinhamento: 'right' },
            { x: 460, largura: 85, texto: 'Total', alinhamento: 'right' },
        ];

        doc.font('Helvetica-Bold').fontSize(9).fillColor('#555555');
        linhaTabela(doc, doc.y, colItens);
        doc.fillColor('black');
        doc.moveDown(0.3);
        doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
        doc.strokeColor('black').lineWidth(1);
        doc.moveDown(0.3);

        // Linhas de itens
        let subtotal = 0;
        pedido.itens_pedido.forEach((item, idx) => {
            const nome = item.produtos?.nome || '—';
            const qtd = item.quantidade;
            const preco = parseFloat(item.valor_unitario);
            const totalItem = preco * qtd;
            subtotal += totalItem;

            const y = doc.y;

            // Fundo alternado
            if (idx % 2 === 0) {
                doc.rect(50, y - 2, 495, 16).fill('#f9f9f9');
            }

            doc.font('Helvetica').fontSize(9).fillColor('black');
            linhaTabela(doc, y, [
                { x: 50, largura: 250, texto: nome },
                { x: 310, largura: 45, texto: String(qtd), alinhamento: 'center' },
                { x: 365, largura: 85, texto: moeda(preco), alinhamento: 'right' },
                { x: 460, largura: 85, texto: moeda(totalItem), alinhamento: 'right' },
            ]);
            doc.moveDown(0.45);
        });

        doc.moveDown(0.5);

        // ── TOTAIS ──────────────────────────────────────────────────────────────

        linha(doc);
        doc.moveDown(0.4);

        const ajuste = parseFloat(pedido.ajuste || 0);
        const total = parseFloat(pedido.valor_total);

        const linhaValor = (label, valor, bold = false, cor = 'black') => {
            const y = doc.y;
            doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(10)
                .fillColor('#555555').text(label, 320, y, { lineBreak: false });
            doc.font(bold ? 'Helvetica-Bold' : 'Helvetica')
                .fillColor(cor).text(moeda(valor), 460, y, { width: 85, align: 'right' });
            doc.fillColor('black');
            doc.moveDown(0.4);
        };

        if (ajuste !== 0) linhaValor('Subtotal', subtotal);
        if (ajuste < 0) linhaValor('Desconto', Math.abs(ajuste), false, '#1565c0');
        if (ajuste > 0) linhaValor('Acréscimo', ajuste, false, '#e65100');

        // Linha separadora acima do total
        doc.moveTo(310, doc.y).lineTo(545, doc.y).strokeColor('#aaaaaa').lineWidth(0.5).stroke();
        doc.strokeColor('black').lineWidth(1);
        doc.moveDown(0.3);
        linhaValor('TOTAL', total, true, '#1b5e20');
        doc.moveDown(0.5);

        // ── PAGAMENTOS ──────────────────────────────────────────────────────────

        linha(doc);
        doc.moveDown(0.5);
        doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20').text('PAGAMENTOS RECEBIDOS');
        doc.fillColor('black');
        doc.moveDown(0.4);

        if (pagamentosReais.length === 0) {
            doc.font('Helvetica').fontSize(9).fillColor('#888888')
                .text('Nenhum pagamento recebido até o momento.');
            doc.fillColor('black');
        } else {
            pagamentosReais.forEach(pag => {
                const y = doc.y;
                doc.font('Helvetica').fontSize(9).fillColor('black');
                linhaTabela(doc, y, [
                    { x: 50, largura: 220, texto: pag.forma_pagamento },
                    { x: 280, largura: 170, texto: formatarData(pag.criado_em), alinhamento: 'left' },
                    { x: 460, largura: 85, texto: moeda(pag.valor_pago), alinhamento: 'right' },
                ]);
                doc.moveDown(0.45);

                // Conta para a qual o pagamento entrou
                if (pag.conta) {
                    doc.font('Helvetica-Oblique').fontSize(8).fillColor('#666666')
                        .text(`Conta: ${pag.conta}`, 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }

                // Pagador, quando diferente do cliente
                if (pag.nome_pagador) {
                    const detalhePagador = pag.cpf_cnpj_pagador
                        ? `Pago por: ${pag.nome_pagador} (${pag.cpf_cnpj_pagador})`
                        : `Pago por: ${pag.nome_pagador}`;
                    doc.font('Helvetica-Oblique').fontSize(8).fillColor('#666666')
                        .text(detalhePagador, 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }
            });
        }

        // Crediário (A receber)
        if (saldoCredito > 0.005) {
            doc.moveDown(0.3);
            const y = doc.y;
            doc.font('Helvetica-Bold').fontSize(10).fillColor('#e65100')
                .text('A receber (crediário):', 50, y, { lineBreak: false });
            doc.text(moeda(saldoCredito), 460, y, { width: 85, align: 'right' });
            doc.fillColor('black');
        }

        // ── RODAPÉ ──────────────────────────────────────────────────────────────

        doc.moveDown(3);
        linha(doc);
        doc.moveDown(0.4);
        doc.font('Helvetica').fontSize(8).fillColor('#aaaaaa')
            .text(`Viveiro Promudas — documento gerado em ${formatarData(new Date())}`, { align: 'center' });

        doc.end();
    });
};

module.exports = { gerarPedidoPDF };
