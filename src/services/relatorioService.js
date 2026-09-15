const PDFDocument = require('pdfkit');
const prisma = require('../config/database');
const { formatarNumeroPedido } = require('../utils/numeroPedido');
const { formatarMoeda } = require('../utils/moeda');
const { formatar: formatarCpfCnpj } = require('../utils/cpfCnpj');
const BusinessError = require('../utils/BusinessError');

const moeda = formatarMoeda;

const formatarData = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    const dia = String(dt.getDate()).padStart(2, '0');
    const mes = String(dt.getMonth() + 1).padStart(2, '0');
    const hora = String(dt.getHours()).padStart(2, '0');
    const min = String(dt.getMinutes()).padStart(2, '0');
    return `${dia}/${mes}/${dt.getFullYear()}  ${hora}:${min}`;
};

const formatarDataCurta = (d) => {
    if (!d) return '—';
    const dt = new Date(d);
    const dia = String(dt.getDate()).padStart(2, '0');
    const mes = String(dt.getMonth() + 1).padStart(2, '0');
    return `${dia}/${mes}/${dt.getFullYear()}`;
};

// Mesmo padrão de exibição de telefone usado em pdfService.js — duplicado aqui
// (arquivo próprio, sem import cruzado) por consistência visual entre os PDFs.
const formatarTelefone = (telefone) => {
    if (!telefone || !String(telefone).trim()) return '';
    const digitos = String(telefone).replace(/\D/g, '');
    if (digitos.length === 11) return `(${digitos.slice(0, 2)}) ${digitos.slice(2, 7)}-${digitos.slice(7)}`;
    if (digitos.length === 10) return `(${digitos.slice(0, 2)}) ${digitos.slice(2, 6)}-${digitos.slice(6)}`;
    return String(telefone).trim();
};

const linhaHorizontal = (doc, cor = '#cccccc') => {
    doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor(cor).lineWidth(0.5).stroke();
    doc.strokeColor('black').lineWidth(1);
};

// Converte um parâmetro de data do relatório. Data inválida virava
// `Invalid Date` e estourava 500; e um "até" sem hora (ex.: "2026-09-09")
// virava meia-noite, excluindo os pagamentos do próprio dia.
const _parsearData = (valor, campo, { fimDoDia = false } = {}) => {
    if (!valor) return undefined;

    const data = new Date(valor);
    if (Number.isNaN(data.getTime())) {
        throw new BusinessError(`Data inválida no campo "${campo}".`);
    }

    const soData = typeof valor === 'string' && !valor.includes('T');
    if (fimDoDia && soData) {
        data.setHours(23, 59, 59, 999);
    }
    return data;
};

const _montarWhere = ({ de, ate, forma }) => {
    const inicio = _parsearData(de, 'de');
    const fim = _parsearData(ate, 'ate', { fimDoDia: true });

    // TODO: quando data_pagamento se tornar obrigatório, remover o OR e filtrar só por data_pagamento
    const whereData = (inicio || fim) ? {
        OR: [
            {
                data_pagamento: {
                    ...(inicio && { gte: inicio }),
                    ...(fim && { lte: fim }),
                }
            },
            {
                data_pagamento: null,
                criado_em: {
                    ...(inicio && { gte: inicio }),
                    ...(fim && { lte: fim }),
                }
            }
        ]
    } : {};

    return {
        ...whereData,
        ...(forma ? { forma_pagamento: forma } : {}),
        // Sem isso o relatório somava pagamentos de pedidos cancelados/apagados
        // e inflava o faturamento (listarPagamentos já filtrava, o relatório não).
        pedidos: { ativo: true },
    };
};

// Filtro de pedidos usado pelo relatório em JSON e pelo PDF — era duplicado
// verbatim nos dois, com risco de divergirem numa mudança futura.
const _montarWherePedidos = ({ de, ate, statusPagamento, statusEntrega, clienteId }) => ({
    ativo: true,
    ...(de || ate ? {
        criado_em: {
            ...(de && { gte: _parsearData(de, 'de') }),
            ...(ate && { lte: _parsearData(ate, 'ate', { fimDoDia: true }) }),
        }
    } : {}),
    ...(statusPagamento ? { status_pagamento: statusPagamento } : {}),
    ...(statusEntrega ? { status_entrega: statusEntrega } : {}),
    ...(clienteId ? { cliente_id: parseInt(clienteId) } : {}),
});

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
                        temporada_ano: true,
                        numero_temporada: true,
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
            .text('Viveiro ProMudas', { align: 'center' });
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
                // criado_em é Timestamp (tem a hora real); data_pagamento é só data
                // (@db.Date) e renderiza sempre meia-noite UTC = 21:00 em UTC-3.
                const dataEfetiva = pag.criado_em || pag.data_pagamento;
                const pedidoId = pag.pedidos ? formatarNumeroPedido(pag.pedidos) : '—';
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

                // Pagador, quando diferente do cliente
                if (pag.nome_pagador) {
                    doc.font('Helvetica-Oblique').fontSize(7).fillColor('#888888')
                        .text(`Pago por: ${pag.nome_pagador}`, 143, doc.y, { width: 312, lineBreak: false });
                    doc.fillColor('black');
                    doc.moveDown(0.35);
                }
                idxDet++;
            });
        }

        // ── RODAPÉ ─────────────────────────────────────────────────────────
        doc.moveDown(2);
        linhaHorizontal(doc);
        doc.moveDown(0.4);
        doc.font('Helvetica').fontSize(8).fillColor('#aaaaaa')
            .text(`Viveiro ProMudas — documento gerado em ${formatarData(new Date())}`, { align: 'center' });

        doc.end();
    });
};

const relatorioPedidos = async ({ de, ate, statusPagamento, statusEntrega, clienteId }) => {
    const where = _montarWherePedidos({ de, ate, statusPagamento, statusEntrega, clienteId });

    const pedidos = await prisma.pedidos.findMany({
        where,
        select: {
            id: true,
            temporada_ano: true,
            numero_temporada: true,
            valor_total: true,
            status_pagamento: true,
            status_entrega: true,
            criado_em: true,
            clientes: { select: { nome: true } },
            _count: { select: { itens_pedido: true } },
        },
        orderBy: { criado_em: 'desc' },
    });

    const valorTotal = pedidos.reduce((s, p) => s + parseFloat(p.valor_total ?? 0), 0);

    // A coluna é nullable e pode ter valor fora deste conjunto: sem o fallback,
    // `porStatusPagamento[undefined]++` gerava NaN e criava a chave "null".
    const porStatusPagamento = { Pago: 0, Crédito: 0, Parcial: 0, Pendente: 0 };
    pedidos.forEach(p => {
        const status = p.status_pagamento ?? 'Pendente';
        porStatusPagamento[status] = (porStatusPagamento[status] ?? 0) + 1;
    });

    return {
        resumo: { total: pedidos.length, valorTotal, porStatusPagamento },
        lista: pedidos.map(p => ({
            id: p.id,
            temporada_ano: p.temporada_ano,
            numero_temporada: p.numero_temporada,
            cliente: p.clientes?.nome ?? '—',
            criado_em: p.criado_em,
            valor_total: parseFloat(p.valor_total),
            status_pagamento: p.status_pagamento,
            status_entrega: p.status_entrega,
            qtd_itens: p._count.itens_pedido,
        })),
    };
};

const gerarRelatorioPedidosPDF = async ({ de, ate, statusPagamento, statusEntrega, clienteId }) => {
    const where = _montarWherePedidos({ de, ate, statusPagamento, statusEntrega, clienteId });

    // Sem período informado, isto carregaria todos os pedidos com itens,
    // pagamentos e entregas aninhados de uma vez.
    const LIMITE_PDF_PEDIDOS = 2000;

    const [totalEncontrados, agregado, pedidos] = await Promise.all([
        prisma.pedidos.count({ where }),
        prisma.pedidos.aggregate({ where, _sum: { valor_total: true } }),
        prisma.pedidos.findMany({
            where,
            take: LIMITE_PDF_PEDIDOS,
            include: {
                clientes: { select: { nome: true, cpf_cnpj: true, cidade: true, estado: true, telefone_1: true } },
                itens_pedido: {
                    include: {
                        produtos: { select: { nome: true } },
                    },
                },
                pagamentos: {
                    orderBy: { criado_em: 'asc' },
                },
                entregas: {
                    orderBy: { criado_em: 'asc' },
                    include: {
                        itens_entrega: {
                            include: { produtos: { select: { nome: true } } },
                        },
                    },
                },
            },
            orderBy: { criado_em: 'desc' },
        }),
    ]);
    // Query ordena por criado_em desc, então o corte sempre mostra os mais recentes.
    const truncado = totalEncontrados > pedidos.length;
    const valorTotalGeral = parseFloat(agregado._sum.valor_total ?? 0);

    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        const paginaFundo = doc.page.height - doc.page.margins.bottom;

        // ── CABEÇALHO ──────────────────────────────────────────────────────
        doc.font('Helvetica-Bold').fontSize(20).fillColor('#1b5e20')
            .text('Viveiro ProMudas', { align: 'center' });
        doc.font('Helvetica').fontSize(10).fillColor('#555555')
            .text('Relatório de Pedidos', { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.5);

        const periodoParts = [];
        if (de) periodoParts.push(`De: ${formatarDataCurta(de)}`);
        if (ate) periodoParts.push(`Até: ${formatarDataCurta(ate)}`);
        if (!de && !ate) periodoParts.push('Todo o período');
        if (statusPagamento) periodoParts.push(`Pagamento: ${statusPagamento}`);
        if (statusEntrega) periodoParts.push(`Entrega: ${statusEntrega}`);

        doc.font('Helvetica').fontSize(9).fillColor('#777777')
            .text(periodoParts.join('   '), { align: 'center' });
        doc.fillColor('black');
        doc.moveDown(0.6);

        linhaHorizontal(doc);
        doc.moveDown(0.5);

        // ── AVISO DE TRUNCAMENTO ───────────────────────────────────────────
        if (truncado) {
            const yAviso = doc.y;
            doc.rect(50, yAviso - 2, 495, 24).fill('#fff3cd');
            doc.font('Helvetica-Bold').fontSize(9).fillColor('#856404')
                .text(
                    `Atenção: exibindo apenas os ${pedidos.length} pedidos mais recentes de ${totalEncontrados} encontrados. Refine o período para ver os demais.`,
                    58, yAviso + 4, { width: 479 }
                );
            doc.fillColor('black');
            doc.moveDown(1.2);
        }

        // ── RESUMO ─────────────────────────────────────────────────────────
        // Soma do valor total usa o agregado (todos os pedidos encontrados), não só
        // os exibidos — senão o "Valor total" ficaria errado quando truncado.
        const yRes = doc.y;
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#555555');
        doc.text(
            truncado ? `Pedidos exibidos: ${pedidos.length} de ${totalEncontrados}` : `Total de pedidos: ${pedidos.length}`,
            50, yRes, { lineBreak: false }
        );
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#1b5e20')
            .text(`Valor total: ${moeda(valorTotalGeral)}`, 300, yRes, { width: 245, align: 'right' });
        doc.fillColor('black');
        doc.moveDown(1);

        if (pedidos.length === 0) {
            doc.font('Helvetica').fontSize(10).fillColor('#888888')
                .text('Nenhum pedido encontrado para os filtros aplicados.', { align: 'center' });
            doc.fillColor('black');
        }

        // ── PEDIDOS ────────────────────────────────────────────────────────
        pedidos.forEach((pedido) => {
            // Estima altura mínima do bloco: cabeçalho (30) + itens (14 cada) + pagamentos (14 cada) + margem (20)
            const alturaEstimada = 30 + (pedido.itens_pedido.length * 14) + (pedido.pagamentos.length * 14) + 20;
            // Quebra de página se não há espaço suficiente para ao menos o cabeçalho do pedido
            if (doc.y + Math.min(alturaEstimada, 60) > paginaFundo) {
                doc.addPage();
            }

            // CPF/CNPJ e cidade/UF do cliente, ao lado do nome — omitidos quando
            // o cadastro não tem o dado.
            const detalhesCliente = [];
            if (pedido.clientes?.cpf_cnpj) detalhesCliente.push(formatarCpfCnpj(pedido.clientes.cpf_cnpj));
            const cidadeUf = [pedido.clientes?.cidade, pedido.clientes?.estado].filter(Boolean).join('/');
            if (cidadeUf) detalhesCliente.push(cidadeUf);
            const nomeCliente = pedido.clientes?.nome ?? '—';
            // Só um espaço em cada "·": com espaço duplo, o PDFKit quebra linha
            // sozinho mesmo com `lineBreak:false` (bug observado na prática).
            const linhaCliente = detalhesCliente.length > 0
                ? `${nomeCliente} · ${detalhesCliente.join(' · ')}`
                : nomeCliente;

            const linhaTelefone = pedido.clientes?.telefone_1
                ? formatarTelefone(pedido.clientes.telefone_1)
                : '';

            // Cabeçalho do pedido — a coluna do cliente (nome + CPF/cidade) quebra
            // linha quando não cabe, em vez de truncar; a caixa verde cresce pra
            // acompanhar (até um teto de 3 linhas, com reticências só nesse caso
            // extremo — texto nunca ultrapassa o fundo da caixa). O telefone, se
            // houver, fica numa linha própria logo abaixo, na mesma coluna.
            doc.font('Helvetica').fontSize(9);
            const larguraCliente = 235;
            const alturaLinha = doc.currentLineHeight();
            const maxLinhasCliente = 3;
            const alturaClienteTexto = Math.min(
                doc.heightOfString(linhaCliente, { width: larguraCliente }),
                alturaLinha * maxLinhasCliente
            );
            const alturaTelefone = linhaTelefone ? alturaLinha : 0;
            const alturaCabecalho = Math.max(20, alturaClienteTexto + alturaTelefone + 10);

            const yPed = doc.y;
            doc.rect(50, yPed, 495, alturaCabecalho).fill('#e8f5e9');
            doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20')
                .text(`Pedido ${formatarNumeroPedido(pedido)}`, 56, yPed + 4, { width: 120, lineBreak: false });
            doc.font('Helvetica').fontSize(9).fillColor('#333333')
                .text(linhaCliente, 185, yPed + 5, {
                    width: larguraCliente,
                    height: alturaLinha * maxLinhasCliente,
                    ellipsis: true,
                });
            if (linhaTelefone) {
                doc.text(linhaTelefone, 185, yPed + 5 + alturaClienteTexto, {
                    width: larguraCliente,
                    lineBreak: false,
                });
            }
            doc.font('Helvetica').fontSize(9).fillColor('#555555')
                .text(formatarDataCurta(pedido.criado_em), 430, yPed + 5, { width: 110, align: 'right' });
            doc.fillColor('black');
            doc.y = yPed + alturaCabecalho + 8;

            // Status
            const yStatus = doc.y;
            doc.font('Helvetica').fontSize(8).fillColor('#555555');
            doc.text(`Pagamento: ${pedido.status_pagamento}`, 56, yStatus, { lineBreak: false });
            doc.text(`Entrega: ${pedido.status_entrega}`, 200, yStatus, { lineBreak: false });

            // Valor total e ajuste
            const ajuste = parseFloat(pedido.ajuste ?? 0);
            const subtotal = parseFloat(pedido.valor_total) - ajuste;
            if (ajuste !== 0) {
                const tipoAjuste = ajuste > 0 ? `Acréscimo: ${moeda(ajuste)}` : `Desconto: ${moeda(Math.abs(ajuste))}`;
                doc.text(tipoAjuste, 350, yStatus, { width: 195, align: 'right' });
            }
            doc.moveDown(0.5);

            doc.font('Helvetica-Bold').fontSize(10).fillColor('#1b5e20');
            const yValor = doc.y;
            doc.text(`Total: ${moeda(pedido.valor_total)}`, 350, yValor, { width: 195, align: 'right' });
            doc.fillColor('black');
            doc.moveDown(0.5);

            // ── Itens do pedido ────────────────────────────────────────────
            // Quebra ANTES do cabeçalho da seção: sem isso, o `doc.text(...)` do
            // cabeçalho podia disparar a paginação automática do PDFKit sozinho
            // (quando `doc.y` já estava colado no rodapé), deixando o rótulo na
            // página nova mas as colunas seguintes usando o `y` antigo (capturado
            // ANTES da quebra) — texto ia parar fora da página, seção "sumia".
            if (doc.y + 35 > paginaFundo) { doc.addPage(); }
            doc.moveTo(56, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
            doc.strokeColor('black').lineWidth(1);
            doc.moveDown(0.3);

            const yItensCab = doc.y;
            doc.font('Helvetica-Bold').fontSize(8).fillColor('#777777');
            doc.text('Produto', 56, yItensCab, { width: 260, lineBreak: false });
            doc.text('Qtd', 320, yItensCab, { width: 60, align: 'center', lineBreak: false });
            doc.text('Unit.', 385, yItensCab, { width: 75, align: 'right', lineBreak: false });
            doc.text('Subtotal', 463, yItensCab, { width: 82, align: 'right' });
            doc.fillColor('black');
            doc.moveDown(0.3);

            pedido.itens_pedido.forEach((item, idx) => {
                if (doc.y + 14 > paginaFundo) { doc.addPage(); }
                const yItem = doc.y;
                if (idx % 2 === 0) doc.rect(56, yItem - 1, 489, 13).fill('#f9f9f9');
                doc.font('Helvetica').fontSize(8).fillColor('black');
                doc.text(item.produtos?.nome ?? '—', 56, yItem, { width: 260, lineBreak: false });
                doc.text(String(item.quantidade), 320, yItem, { width: 60, align: 'center', lineBreak: false });
                doc.text(moeda(item.valor_unitario), 385, yItem, { width: 75, align: 'right', lineBreak: false });
                doc.text(moeda(parseFloat(item.valor_unitario) * item.quantidade), 463, yItem, { width: 82, align: 'right' });
                doc.moveDown(0.4);
            });

            // ── Pagamentos ─────────────────────────────────────────────────
            if (pedido.pagamentos.length > 0) {
                doc.moveDown(0.3);
                // Ver comentário equivalente na seção de itens acima — mesmo risco aqui.
                if (doc.y + 35 > paginaFundo) { doc.addPage(); }
                doc.moveTo(56, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
                doc.strokeColor('black').lineWidth(1);
                doc.moveDown(0.3);

                const yPagCab = doc.y;
                doc.font('Helvetica-Bold').fontSize(8).fillColor('#777777');
                doc.text('Pagamentos', 56, yPagCab, { width: 200, lineBreak: false });
                doc.text('Forma', 260, yPagCab, { width: 140, lineBreak: false });
                doc.text('Data', 403, yPagCab, { width: 80, lineBreak: false });
                doc.text('Valor', 463, yPagCab, { width: 82, align: 'right' });
                doc.fillColor('black');
                doc.moveDown(0.3);

                pedido.pagamentos.forEach((pag) => {
                    if (doc.y + 14 > paginaFundo) { doc.addPage(); }
                    const yPag = doc.y;
                    const nomeFP = pag.forma_pagamento ?? '—';
                    const dataPag = formatarDataCurta(pag.data_pagamento || pag.criado_em);
                    const pagador = pag.nome_pagador ? `Pago por: ${pag.nome_pagador}` : '';
                    doc.font('Helvetica').fontSize(8).fillColor('#666666');
                    doc.text(pagador, 56, yPag, { width: 200, lineBreak: false });
                    doc.fillColor('black');
                    doc.text(nomeFP, 260, yPag, { width: 140, lineBreak: false });
                    doc.text(dataPag, 403, yPag, { width: 80, lineBreak: false });
                    doc.text(moeda(pag.valor_pago), 463, yPag, { width: 82, align: 'right' });
                    doc.moveDown(0.4);
                });
            }

            // ── Entregas ───────────────────────────────────────────────────
            if (pedido.entregas.length > 0) {
                doc.moveDown(0.3);
                // Ver comentário equivalente na seção de itens acima — mesmo risco aqui.
                if (doc.y + 35 > paginaFundo) { doc.addPage(); }
                doc.moveTo(56, doc.y).lineTo(545, doc.y).strokeColor('#dddddd').lineWidth(0.5).stroke();
                doc.strokeColor('black').lineWidth(1);
                doc.moveDown(0.3);

                doc.font('Helvetica-Bold').fontSize(8).fillColor('#777777')
                    .text('Entregas', 56, doc.y);
                doc.fillColor('black');
                doc.moveDown(0.2);

                pedido.entregas.forEach((ret) => {
                    if (doc.y + 14 > paginaFundo) { doc.addPage(); }
                    const dataRet = formatarDataCurta(ret.data_entrega || ret.criado_em);
                    const local = ret.local_entrega ?? '—';
                    const veiculo = [ret.motorista, ret.placa_veiculo].filter(Boolean).join(' · ');
                    const cabecalho = `${dataRet}  ·  Local: ${local}${veiculo ? '  ·  ' + veiculo : ''}`;
                    doc.font('Helvetica-Bold').fontSize(8).fillColor('#555555')
                        .text(cabecalho, 56, doc.y, { width: 489 });
                    doc.fillColor('black');
                    doc.moveDown(0.15);

                    ret.itens_entrega.forEach((it) => {
                        if (doc.y + 12 > paginaFundo) { doc.addPage(); }
                        const yIt = doc.y;
                        const nomeProd = it.produtos?.nome ?? '—';
                        doc.font('Helvetica').fontSize(8).fillColor('#333333');
                        doc.text(`• ${nomeProd}`, 66, yIt, { width: 380, lineBreak: false });
                        doc.text(`${it.quantidade}x`, 463, yIt, { width: 82, align: 'right' });
                        doc.fillColor('black');
                        doc.moveDown(0.35);
                    });
                });
            }

            doc.moveDown(0.8);
            linhaHorizontal(doc, '#eeeeee');
            doc.moveDown(0.6);
        });

        // ── RODAPÉ ─────────────────────────────────────────────────────────
        doc.font('Helvetica').fontSize(8).fillColor('#aaaaaa')
            .text(`Viveiro ProMudas — documento gerado em ${formatarData(new Date())}`, { align: 'center' });

        doc.end();
    });
};

module.exports = { relatorioPagamentos, gerarRelatorioPDF, relatorioPedidos, gerarRelatorioPedidosPDF };
