const PDFDocument = require('pdfkit');
const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const formaPagamentoService = require('./formaPagamentoService');
const { formatarNumeroPedido } = require('../utils/numeroPedido');
const { formatarNumeroOrcamento } = require('../utils/numeroOrcamento');
const { formatarMoeda } = require('../utils/moeda');
const { formatar: formatarCpfCnpj } = require('../utils/cpfCnpj');

const moeda = formatarMoeda;

// Escala global das fontes do recibo. Aumentar/diminuir aqui afeta o documento todo.
const ESCALA_FONTE = 1.25;
const fs = (n) => n * ESCALA_FONTE;

const formatarCep = (cep) => (cep && cep.length === 8 ? `${cep.slice(0, 5)}-${cep.slice(5)}` : cep);

// Nome e telefone seguem no PDF o mesmo padrão de exibição das telas do app
// (capitalizarNome/formatarTelefone em core/utils/formatadores.dart) — o valor
// gravado no banco continua sendo o que o usuário digitou.
const capitalizarNome = (nome) => String(nome ?? '')
    .trim()
    .split(/\s+/)
    .map((palavra) => (palavra ? palavra[0].toUpperCase() + palavra.slice(1).toLowerCase() : palavra))
    .join(' ');

const formatarTelefone = (telefone) => {
    if (!telefone || !String(telefone).trim()) return '';
    const digitos = String(telefone).replace(/\D/g, '');
    if (digitos.length === 11) return `(${digitos.slice(0, 2)}) ${digitos.slice(2, 7)}-${digitos.slice(7)}`;
    if (digitos.length === 10) return `(${digitos.slice(0, 2)}) ${digitos.slice(2, 6)}-${digitos.slice(6)}`;
    return String(telefone).trim();
};

const formatarData = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    const dia = String(dt.getDate()).padStart(2, '0');
    const mes = String(dt.getMonth() + 1).padStart(2, '0');
    const hora = String(dt.getHours()).padStart(2, '0');
    const min = String(dt.getMinutes()).padStart(2, '0');
    return `${dia}/${mes}/${dt.getFullYear()}  ${hora}:${min}`;
};

// Formata só a data (sem hora) — usado em campos @db.Date, como a emissão da nota.
const formatarSoData = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    const dia = String(dt.getDate()).padStart(2, '0');
    const mes = String(dt.getMonth() + 1).padStart(2, '0');
    return `${dia}/${mes}/${dt.getFullYear()}`;
};

// Pontos por milímetro (PDFKit trabalha em pontos: 72 pt = 1 polegada = 25,4 mm)
const MM = 72 / 25.4;

// Desenha os guias de furação no lado esquerdo, para arquivar o recibo numa pasta.
// Dois furos espaçados 80 mm entre centros, centralizados na vertical da folha A4.
// O furador tem furo de 6 mm; o guia é um círculo de 10 mm para sobrar margem de mira.
const desenharGuiasFuro = (doc) => {
    const centroX = 12 * MM;                   // 12 mm da borda esquerda (dentro da margem de 50 pt)
    const centroVertical = doc.page.height / 2;
    const meioVao = 40 * MM;                   // metade dos 80 mm entre os furos
    const raioGuia = 5 * MM;                    // círculo-guia de 10 mm de diâmetro
    [centroVertical - meioVao, centroVertical + meioVao].forEach((cy) => {
        doc.circle(centroX, cy, raioGuia).lineWidth(0.7).strokeColor('black').stroke();
    });
    doc.lineWidth(1).strokeColor('black');     // restaura o padrão para o resto do desenho
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

// ─────────────────────────────────────────────────────────────────────────
// Seções de desenho compartilhadas entre o PDF de pedido e o de orçamento
// (mesmo estilo visual — ver comentário de `gerarOrcamentoPDF`).
// ─────────────────────────────────────────────────────────────────────────

// Bloco "CLIENTE": nome, CPF/CNPJ, telefone e endereço (só os campos preenchidos).
const desenharCliente = (doc, cliente) => {
    linha(doc);
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(fs(10)).fillColor('#1b5e20').text('CLIENTE', 50, doc.y);
    doc.fillColor('black');
    doc.moveDown(0.2);
    doc.font('Helvetica-Bold').fontSize(fs(11)).text(capitalizarNome(cliente?.nome) || '—');

    doc.font('Helvetica').fontSize(fs(9)).fillColor('#555555');

    if (cliente?.cpf_cnpj) doc.text(`CPF/CNPJ: ${formatarCpfCnpj(cliente.cpf_cnpj)}`);
    if (cliente?.telefone_1) doc.text(`Telefone: ${formatarTelefone(cliente.telefone_1)}`);

    // Endereço sai todo em maiúsculas (padrão de etiqueta/correspondência).
    if (cliente?.logradouro) {
        const linha1 = [cliente.logradouro, cliente.numero]
            .filter(Boolean).join(', ').toUpperCase();
        const linha2Parts = [
            cliente.bairro?.toUpperCase(),
            cliente.cidade && cliente.estado
                ? `${cliente.cidade}/${cliente.estado}`.toUpperCase()
                : (cliente.cidade || cliente.estado || '').toUpperCase(),
            formatarCep(cliente.cep),
        ].filter(Boolean);
        doc.text(linha1);
        if (linha2Parts.length > 0) doc.text(linha2Parts.join(' — '));
    }

    doc.fillColor('black');
    doc.moveDown(0.8);
};

// Bloco "ITENS": cabeçalho da tabela + uma linha por item, com fundo alternado.
// Retorna o subtotal (soma de preço × quantidade) para o bloco de totais.
const desenharItens = (doc, titulo, itens) => {
    linha(doc);
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(fs(10)).fillColor('#1b5e20').text(titulo, 50, doc.y);
    doc.fillColor('black');
    doc.moveDown(0.4);

    const colItens = [
        { x: 50, largura: 250, texto: 'Produto' },
        { x: 310, largura: 45, texto: 'Qtd', alinhamento: 'center' },
        { x: 365, largura: 85, texto: 'Preço Unit.', alinhamento: 'right' },
        { x: 460, largura: 85, texto: 'Total', alinhamento: 'right' },
    ];

    doc.font('Helvetica-Bold').fontSize(fs(9)).fillColor('#555555');
    linhaTabela(doc, doc.y, colItens);
    doc.fillColor('black');
    doc.moveDown(0.3);
    doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
    doc.strokeColor('black').lineWidth(1);
    doc.moveDown(0.3);

    let subtotal = 0;
    itens.forEach((item, idx) => {
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

        doc.font('Helvetica').fontSize(fs(9)).fillColor('black');
        linhaTabela(doc, y, [
            { x: 50, largura: 250, texto: nome },
            { x: 310, largura: 45, texto: String(qtd), alinhamento: 'center' },
            { x: 365, largura: 85, texto: moeda(preco), alinhamento: 'right' },
            { x: 460, largura: 85, texto: moeda(totalItem), alinhamento: 'right' },
        ]);
        doc.moveDown(0.45);
    });

    doc.moveDown(0.5);
    return subtotal;
};

// Desenha uma linha "label ......... valor" no bloco de totais.
const desenharLinhaValor = (doc, label, valor, bold = false, cor = 'black') => {
    const y = doc.y;
    doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(fs(10))
        .fillColor('#555555').text(label, 320, y, { lineBreak: false });
    doc.font(bold ? 'Helvetica-Bold' : 'Helvetica')
        .fillColor(cor).text(moeda(valor), 460, y, { width: 85, align: 'right' });
    doc.fillColor('black');
    doc.moveDown(0.4);
};

// Bloco "TOTAIS": subtotal/desconto/acréscimo (só quando há ajuste) + total em negrito.
const desenharTotais = (doc, { ajuste, total, subtotal }) => {
    linha(doc);
    doc.moveDown(0.4);

    if (ajuste !== 0) desenharLinhaValor(doc, 'Subtotal', subtotal);
    if (ajuste < 0) desenharLinhaValor(doc, 'Desconto', Math.abs(ajuste), false, '#1565c0');
    if (ajuste > 0) desenharLinhaValor(doc, 'Acréscimo', ajuste, false, '#e65100');

    // Linha separadora acima do total
    doc.moveTo(310, doc.y).lineTo(545, doc.y).strokeColor('#aaaaaa').lineWidth(0.5).stroke();
    doc.strokeColor('black').lineWidth(1);
    doc.moveDown(0.3);
    desenharLinhaValor(doc, 'TOTAL', total, true, '#1b5e20');
    doc.moveDown(0.5);
};

// Bloco "OBSERVAÇÕES" — omitido inteiramente quando vazio.
const desenharObservacoes = (doc, observacoes) => {
    if (!observacoes || !observacoes.trim()) return;
    linha(doc);
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(fs(10)).fillColor('#1b5e20').text('OBSERVAÇÕES', { align: 'right' });
    doc.fillColor('black');
    doc.moveDown(0.3);
    doc.font('Helvetica').fontSize(fs(9)).fillColor('#333333')
        .text(observacoes.trim(), 50, doc.y, { width: 495, align: 'right' });
    doc.fillColor('black');
    doc.moveDown(0.5);
};

// Altura reservada para o rodapé (linha separadora + uma linha de texto).
const ALTURA_RODAPE = 26;

// Campo de assinatura do vendedor: centralizado e logo acima do rodapé.
// Posição absoluta em relação à página (não flui a partir de doc.y), para
// ficar sempre no mesmo lugar independente do tamanho do conteúdo.
const desenharAssinatura = (doc) => {
    const largura = 240;
    const x = (doc.page.width - largura) / 2;
    const yLinha = doc.page.height - doc.page.margins.bottom - ALTURA_RODAPE - 44;

    doc.moveTo(x, yLinha).lineTo(x + largura, yLinha)
        .strokeColor('#888888').lineWidth(0.7).stroke();
    doc.strokeColor('black').lineWidth(1);

    doc.font('Helvetica').fontSize(fs(8)).fillColor('#555555')
        .text('Assinatura do Vendedor', x, yLinha + 5, { width: largura, align: 'center' });
    doc.fillColor('black');
};

// Rodapé com a data de geração — fixo no pé da página.
const desenharRodape = (doc) => {
    const y = doc.page.height - doc.page.margins.bottom - ALTURA_RODAPE;

    doc.moveTo(50, y).lineTo(545, y).strokeColor('#cccccc').lineWidth(0.5).stroke();
    doc.strokeColor('black').lineWidth(1);

    doc.font('Helvetica').fontSize(fs(8)).fillColor('#aaaaaa')
        .text(`Viveiro Promudas — documento gerado em ${formatarData(new Date())}`,
            50, y + 6, { width: 495, align: 'right' });
    doc.fillColor('black');
};

const gerarPedidoPDF = async (pedidoId, copias = 1) => {
    const [pedido, formasPosteriores] = await Promise.all([
        prisma.pedidos.findUnique({
            where: { id: parseInt(pedidoId), ativo: true },
            include: {
                clientes: true,
                itens_pedido: {
                    include: { produtos: { select: { nome: true } } }
                },
                pagamentos: {
                    orderBy: { criado_em: 'asc' },
                    include: { cheques: { orderBy: { bom_para: 'asc' } } }
                },
                entregas: {
                    orderBy: { criado_em: 'asc' },
                    include: {
                        itens_entrega: {
                            include: { produtos: { select: { nome: true } } }
                        }
                    }
                }
            }
        }),
        formaPagamentoService.listarPosteriores()
    ]);

    if (!pedido) {
        throw new BusinessError('Pedido não encontrado.', 404);
    }

    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));
    const pagamentosReais = pedido.pagamentos.filter(p => !nomesPosteriores.has(p.forma_pagamento));
    const saldoCredito = pedido.pagamentos
        .filter(p => nomesPosteriores.has(p.forma_pagamento))
        .reduce((s, p) => s + parseFloat(p.valor_pago), 0);

    // Nome do arquivo final: "Pedido AA-N.pdf" (AA-N = número por temporada),
    // ou "Pedido #id.pdf" para pedidos sem temporada. Enviado no Content-Disposition.
    const nomeArquivo = `Pedido ${formatarNumeroPedido(pedido)}.pdf`;

    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end', () => resolve({ buffer: Buffer.concat(chunks), nomeArquivo, entidade: pedido }));
        doc.on('error', reject);

        // Guias de furação: na primeira página (já criada pelo construtor) e em cada
        // página nova que vier a ser adicionada se o conteúdo passar de uma folha.
        desenharGuiasFuro(doc);
        doc.on('pageAdded', () => desenharGuiasFuro(doc));

        // Desenha uma via completa do recibo a partir da posição atual do cursor.
        // Chamada `copias` vezes (com `doc.addPage()` entre elas) para imprimir
        // o pedido em várias vias dentro do mesmo PDF.
        const desenharPedido = () => {
        // ── CABEÇALHO ──────────────────────────────────────────────────────────

        doc.font('Helvetica-Bold').fontSize(fs(20)).fillColor('#1b5e20')
            .text('Viveiro Promudas', { align: 'center' });
        doc.font('Helvetica').fontSize(fs(10)).fillColor('#555555')
            .text('Recibo de Pedido', { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.8);

        linha(doc);
        doc.moveDown(0.5);

        // Número e data
        const dataPedido = formatarData(pedido.data_pedido || pedido.criado_em);
        doc.font('Helvetica-Bold').fontSize(fs(14)).text(`PEDIDO ${formatarNumeroPedido(pedido)}`, 50, doc.y, { continued: true });
        doc.font('Helvetica').fontSize(fs(10)).fillColor('#555555')
            .text(dataPedido, { align: 'right' });
        doc.fillColor('black');
        doc.moveDown(0.4);

        // Status — pagamento e entrega, em linhas rotuladas separadas
        const corPagamento = pedido.status_pagamento === 'Pago'
            ? '#1b5e20'
            : pedido.status_pagamento === 'Parcial'
                ? '#e65100'
                : '#555555';
        const corEntrega = (pedido.status_entrega === 'Realizada' || pedido.status_entrega === 'Entregue')
            ? '#1b5e20'
            : pedido.status_entrega === 'Parcial'
                ? '#e65100'
                : '#555555';

        doc.font('Helvetica').fontSize(fs(10)).fillColor('black')
            .text('Status de Pagamento: ', 50, doc.y, { continued: true });
        doc.font('Helvetica-Bold').fillColor(corPagamento).text(pedido.status_pagamento || 'Pendente');
        doc.fillColor('black');
        doc.moveDown(0.2);

        doc.font('Helvetica').fontSize(fs(10)).fillColor('black')
            .text('Status de Entrega: ', 50, doc.y, { continued: true });
        doc.font('Helvetica-Bold').fillColor(corEntrega).text(pedido.status_entrega || 'Pendente');
        doc.fillColor('black');
        doc.moveDown(0.8);

        // ── CLIENTE ─────────────────────────────────────────────────────────────

        desenharCliente(doc, pedido.clientes);

        // ── ITENS ───────────────────────────────────────────────────────────────

        const subtotal = desenharItens(doc, 'ITENS DO PEDIDO', pedido.itens_pedido);

        // ── TOTAIS ──────────────────────────────────────────────────────────────

        const ajuste = parseFloat(pedido.ajuste || 0);
        const total = parseFloat(pedido.valor_total);
        desenharTotais(doc, { ajuste, total, subtotal });

        // ── OBSERVAÇÕES ─────────────────────────────────────────────────────────

        desenharObservacoes(doc, pedido.observacoes);

        // ── PAGAMENTOS ──────────────────────────────────────────────────────────

        linha(doc);
        doc.moveDown(0.5);
        doc.font('Helvetica-Bold').fontSize(fs(10)).fillColor('#1b5e20').text('PAGAMENTOS', 50, doc.y);
        doc.fillColor('black');
        doc.moveDown(0.4);

        if (pagamentosReais.length === 0) {
            doc.font('Helvetica').fontSize(fs(9)).fillColor('#888888')
                .text('Nenhum pagamento recebido até o momento.', 50, doc.y);
            doc.fillColor('black');
        } else {
            // Cabeçalho de colunas: Forma de pagamento | Dia | Valor
            const colPagamentos = [
                { x: 50, largura: 220, texto: 'Forma de pagamento' },
                { x: 280, largura: 170, texto: 'Dia', alinhamento: 'left' },
                { x: 460, largura: 85, texto: 'Valor', alinhamento: 'right' },
            ];
            doc.font('Helvetica-Bold').fontSize(fs(9)).fillColor('#555555');
            linhaTabela(doc, doc.y, colPagamentos);
            doc.fillColor('black');
            doc.moveDown(0.3);
            doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
            doc.strokeColor('black').lineWidth(1);
            doc.moveDown(0.3);

            pagamentosReais.forEach(pag => {
                const y = doc.y;
                doc.font('Helvetica').fontSize(fs(9)).fillColor('black');
                const formaTexto = pag.parcelas > 1
                    ? `${pag.forma_pagamento} (${pag.parcelas}x)`
                    : pag.forma_pagamento;
                linhaTabela(doc, y, [
                    { x: 50, largura: 220, texto: formaTexto },
                    { x: 280, largura: 170, texto: formatarData(pag.data_pagamento || pag.criado_em), alinhamento: 'left' },
                    { x: 460, largura: 85, texto: moeda(pag.valor_pago), alinhamento: 'right' },
                ]);
                doc.moveDown(0.45);

                // Conta para a qual o pagamento entrou
                if (pag.conta) {
                    doc.font('Helvetica-Oblique').fontSize(fs(8)).fillColor('#666666')
                        .text(`Conta: ${pag.conta}`, 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }

                // Escambo (troca): quantidade de produção recebida em kg
                if (pag.escambo_quantidade != null) {
                    doc.font('Helvetica-Oblique').fontSize(fs(8)).fillColor('#666666')
                        .text(`Pimenta: ${parseFloat(pag.escambo_quantidade)} kg`, 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }

                // Pagador, quando diferente do cliente
                if (pag.nome_pagador) {
                    const detalhePagador = pag.cpf_cnpj_pagador
                        ? `Pago por: ${pag.nome_pagador} (${pag.cpf_cnpj_pagador})`
                        : `Pago por: ${pag.nome_pagador}`;
                    doc.font('Helvetica-Oblique').fontSize(fs(8)).fillColor('#666666')
                        .text(detalhePagador, 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }

                // Detalhes dos cheques (pré-datados): número, banco e "bom para"
                (pag.cheques || []).forEach(cheque => {
                    const partes = [
                        cheque.numero ? `Cheque nº ${cheque.numero}` : 'Cheque',
                        cheque.banco,
                        cheque.bom_para ? `bom para ${formatarData(cheque.bom_para)}` : null,
                    ].filter(Boolean);
                    doc.font('Helvetica-Oblique').fontSize(fs(8)).fillColor('#666666')
                        .text(partes.join(' · '), 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                });

                // Nota fiscal — só quando já emitida; pendente não aparece no recibo
                if (pag.status_nota && pag.status_nota !== 'Pendente') {
                    const partesNota = [];
                    if (pag.numero_nota) partesNota.push(`Nota fiscal: ${pag.numero_nota}`);
                    else partesNota.push('Nota fiscal');
                    if (pag.status_nota) partesNota.push(`(${pag.status_nota})`);
                    if (pag.data_emissao_nota) partesNota.push(`emitida em ${formatarSoData(pag.data_emissao_nota)}`);
                    doc.font('Helvetica-Oblique').fontSize(fs(8)).fillColor('#666666')
                        .text(partesNota.join(' '), 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }
            });
        }

        // Crediário (A receber)
        if (saldoCredito > 0.005) {
            doc.moveDown(0.3);
            const y = doc.y;
            doc.font('Helvetica-Bold').fontSize(fs(10)).fillColor('#e65100')
                .text('A receber (crediário):', 50, y, { lineBreak: false });
            doc.text(moeda(saldoCredito), 460, y, { width: 85, align: 'right' });
            doc.fillColor('black');
        }

        // ── ENTREGAS ────────────────────────────────────────────────────────────

        if (pedido.entregas.length > 0) {
            doc.moveDown(0.8);
            linha(doc);
            doc.moveDown(0.5);
            doc.font('Helvetica-Bold').fontSize(fs(10)).fillColor('#1b5e20').text('ENTREGAS', 50, doc.y);
            doc.fillColor('black');
            doc.moveDown(0.4);

            // Cabeçalho de colunas: Produto | Local | Dia | Quantidade
            const colEntregas = [
                { x: 50, largura: 200, texto: 'Produto' },
                { x: 255, largura: 105, texto: 'Local' },
                { x: 365, largura: 120, texto: 'Dia' },
                { x: 490, largura: 55, texto: 'Qtd', alinhamento: 'right' },
            ];
            doc.font('Helvetica-Bold').fontSize(fs(9)).fillColor('#555555');
            linhaTabela(doc, doc.y, colEntregas);
            doc.fillColor('black');
            doc.moveDown(0.3);
            doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
            doc.strokeColor('black').lineWidth(1);
            doc.moveDown(0.3);

            pedido.entregas.forEach((entrega, idx) => {
                // Espaçamento entre entregas múltiplas
                if (idx > 0) doc.moveDown(0.3);

                const local = entrega.local_entrega || '—';
                const dia = formatarData(entrega.data_entrega);

                // Uma linha por item: Produto | Local | Dia | Quantidade
                entrega.itens_entrega.forEach(item => {
                    const nome = item.produtos?.nome || '—';
                    doc.font('Helvetica').fontSize(fs(9)).fillColor('black');
                    linhaTabela(doc, doc.y, [
                        { x: 50, largura: 200, texto: nome },
                        { x: 255, largura: 105, texto: local },
                        { x: 365, largura: 120, texto: dia },
                        { x: 490, largura: 55, texto: `${item.quantidade}x`, alinhamento: 'right' },
                    ]);
                    doc.fillColor('black');
                    doc.moveDown(0.45);
                });

                // Abaixo dos itens: quem pegou (motorista) e placa do veículo
                const detalhes = [];
                if (entrega.motorista && entrega.motorista.trim()) detalhes.push(`Recebido por: ${entrega.motorista.trim()}`);
                if (entrega.placa_veiculo && entrega.placa_veiculo.trim()) detalhes.push(`Placa: ${entrega.placa_veiculo.trim()}`);
                if (detalhes.length > 0) {
                    doc.font('Helvetica-Oblique').fontSize(fs(8)).fillColor('#666666')
                        .text(detalhes.join(' · '), 60, doc.y, { width: 470 });
                    doc.fillColor('black');
                    doc.moveDown(0.4);
                }
            });
        }

        // ── ASSINATURA ──────────────────────────────────────────────────────────

        desenharAssinatura(doc);

        // ── RODAPÉ ──────────────────────────────────────────────────────────────

        desenharRodape(doc);
        };

        for (let i = 0; i < copias; i++) {
            if (i > 0) doc.addPage();
            desenharPedido();
        }

        doc.end();
    });
};

// Gera o PDF de um orçamento: mesmo estilo visual do recibo de pedido
// (cabeçalho, guias de furação, cliente, itens, totais, observações), mas
// sem as seções de Pagamentos/Entregas — orçamento ainda não tem nenhum dos
// dois. Sempre 1 via (orçamento não tem a opção de imprimir 3 vias).
const gerarOrcamentoPDF = async (orcamentoId) => {
    const orcamento = await prisma.orcamentos.findUnique({
        where: { id: parseInt(orcamentoId), ativo: true },
        include: {
            clientes: true,
            itens_orcamento: {
                include: { produtos: { select: { nome: true } } }
            }
        }
    });

    if (!orcamento) {
        throw new BusinessError('Orçamento não encontrado.', 404);
    }

    const nomeArquivo = `Orçamento ${formatarNumeroOrcamento(orcamento)}.pdf`;

    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end', () => resolve({ buffer: Buffer.concat(chunks), nomeArquivo, entidade: orcamento }));
        doc.on('error', reject);

        desenharGuiasFuro(doc);
        doc.on('pageAdded', () => desenharGuiasFuro(doc));

        // ── CABEÇALHO ──────────────────────────────────────────────────────────

        doc.font('Helvetica-Bold').fontSize(fs(20)).fillColor('#1b5e20')
            .text('Viveiro Promudas', { align: 'center' });
        doc.font('Helvetica').fontSize(fs(10)).fillColor('#555555')
            .text('Orçamento', { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.8);

        linha(doc);
        doc.moveDown(0.5);

        const dataOrcamento = formatarData(orcamento.data_orcamento || orcamento.criado_em);
        doc.font('Helvetica-Bold').fontSize(fs(14)).text(`ORÇAMENTO ${formatarNumeroOrcamento(orcamento)}`, 50, doc.y, { continued: true });
        doc.font('Helvetica').fontSize(fs(10)).fillColor('#555555')
            .text(dataOrcamento, { align: 'right' });
        doc.fillColor('black');
        doc.moveDown(0.4);

        const corStatus = orcamento.status === 'Aprovado'
            ? '#1b5e20'
            : orcamento.status === 'Rejeitado'
                ? '#c62828'
                : '#e65100';
        doc.font('Helvetica').fontSize(fs(10)).fillColor('black')
            .text('Status: ', 50, doc.y, { continued: true });
        doc.font('Helvetica-Bold').fillColor(corStatus).text(orcamento.status || 'Pendente');
        doc.fillColor('black');
        doc.moveDown(0.8);

        // ── CLIENTE ─────────────────────────────────────────────────────────────

        desenharCliente(doc, orcamento.clientes);

        // ── ITENS ───────────────────────────────────────────────────────────────

        const subtotal = desenharItens(doc, 'ITENS DO ORÇAMENTO', orcamento.itens_orcamento);

        // ── TOTAIS ──────────────────────────────────────────────────────────────

        const ajuste = parseFloat(orcamento.ajuste || 0);
        const total = parseFloat(orcamento.valor_total);
        desenharTotais(doc, { ajuste, total, subtotal });

        // ── OBSERVAÇÕES ─────────────────────────────────────────────────────────

        desenharObservacoes(doc, orcamento.observacoes);

        // ── ASSINATURA ──────────────────────────────────────────────────────────

        desenharAssinatura(doc);

        // ── RODAPÉ ──────────────────────────────────────────────────────────────

        desenharRodape(doc);

        doc.end();
    });
};

module.exports = { gerarPedidoPDF, gerarOrcamentoPDF };
