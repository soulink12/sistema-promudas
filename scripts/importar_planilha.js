// ============================================================================
// Importação ÚNICA da planilha histórica (safra 2025/2026) para o banco.
//
// Migra as 4 abas (Clientes, Encomenda, Pagamento, Entregas) de um arquivo .xlsx
// para clientes/pedidos/itens/pagamentos/entregas. Roda na máquina do dono, com o
// arquivo REAL (dados sensíveis não passam pela IA). Reaproveita a conexão Prisma
// do .env e as funções de recálculo de status já existentes em produção.
//
// ⚠️ DESTRUTIVO: limpa clientes/pedidos/pagamentos/entregas (preserva Consumidor id=1)
//    antes de importar. Rodar SOMENTE no banco de TESTE, com o .env conferido.
//
// Uso:
//   node scripts/importar_planilha.js "C:\\caminho\\Encomendas...real.xlsx" --confirmar
// ============================================================================

require('dotenv').config(); // carrega DATABASE_* do .env
const path = require('path');
const XLSX = require('xlsx');
const prisma = require('../src/config/database');
const { recalcularStatusPedido } = require('../src/services/pagamentoService');
const { recalcularStatusEntrega } = require('../src/services/entregaService');

// ── Constantes ajustáveis ───────────────────────────────────────────────────
const PRECO_PADRAO = 8.5;          // preço por muda
const TEMPORADA_ANO = 2026;        // pedidos exibem 26-N (N = n° da planilha)
const DATA_PADRAO_PEDIDO = new Date('2025-08-01T00:00:00'); // p/ pedidos sem nenhuma data
const PREFIXO_PRODUTO = 'Muda de pimenta-do-reino ';
const MAX_LOGRADOURO = 150;        // limite da coluna clientes.logradouro

// Siglas de UF válidas — usadas só para detectar quando o endereço indica um
// estado diferente de PA (padrão). Tudo é PA, exceto quando indicado outro.
const UFS = new Set([
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
    'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
]);

// ── Helpers ─────────────────────────────────────────────────────────────────

// Lê uma aba como array-de-arrays (cada linha é um array por índice de coluna),
// pulando o cabeçalho. Datas vêm como Date (cellDates), valores crus (raw).
function lerAba(wb, nome) {
    const ws = wb.Sheets[nome];
    if (!ws) throw new Error(`Aba não encontrada na planilha: "${nome}"`);
    const linhas = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, blankrows: false });
    return linhas;
}

function ehVazio(v) {
    return v === null || v === undefined || v === '';
}

// Converte célula numérica em inteiro de quantidade (>0) ou 0.
function qtd(v) {
    if (ehVazio(v)) return 0;
    const n = Math.round(Number(v));
    return Number.isFinite(n) && n > 0 ? n : 0;
}

function num(v) {
    if (ehVazio(v)) return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
}

function texto(v) {
    if (ehVazio(v)) return null;
    return String(v).trim() || null;
}

// As células de data da planilha são date-only. O SheetJS as devolve com um
// pequeno artefato de hora/timezone (ex.: 00:00:28 -03:00). Normaliza para a
// meia-noite local do dia exibido na planilha → data limpa e dia correto.
function comoData(v) {
    if (!(v instanceof Date) || isNaN(v)) return null;
    return new Date(v.getFullYear(), v.getMonth(), v.getDate());
}

// Forma de pagamento: corta tudo após "/", aplica saneamento combinado pelo dono.
function sanearForma(v) {
    let f = texto(v);
    if (!f) return null;
    f = f.split('/')[0].trim();
    const baixo = f.toLowerCase();
    if (baixo === 'identificar' || baixo === 'troca') return 'Dinheiro';
    return f;
}

// Conta: "BR" e "Pimenta" viram "Caixa"; demais ficam como estão.
function sanearConta(v) {
    const c = texto(v);
    if (!c) return null;
    const baixo = c.toLowerCase();
    if (baixo === 'br' || baixo === 'pimenta') return 'Caixa';
    return c;
}

// Extrai UF do fim do endereço (default PA). Retorna { estado, logradouro }.
function separarEndereco(enderecoRaw) {
    const bruto = texto(enderecoRaw);
    if (!bruto) return { estado: 'PA', logradouro: null };

    let estado = 'PA';
    let logradouro = bruto;

    // Procura uma sigla de UF no fim, precedida por separador (espaço, vírgula, - ou /).
    const m = bruto.match(/[\s,\-/]+([A-Za-z]{2})\s*$/);
    if (m) {
        const uf = m[1].toUpperCase();
        if (UFS.has(uf)) {
            estado = uf;
            logradouro = bruto.slice(0, m.index).replace(/[\s,\-/]+$/, '').trim() || null;
        }
    }

    let truncou = false;
    if (logradouro && logradouro.length > MAX_LOGRADOURO) {
        logradouro = logradouro.slice(0, MAX_LOGRADOURO);
        truncou = true;
    }
    return { estado, logradouro, truncou };
}

// ── Importação ──────────────────────────────────────────────────────────────

async function main() {
    const arquivo = process.argv[2];
    const confirmou = process.argv.includes('--confirmar');

    if (!arquivo) {
        console.error('Uso: node scripts/importar_planilha.js "<caminho do .xlsx>" --confirmar');
        process.exit(1);
    }

    console.log('────────────────────────────────────────────────────────');
    console.log('  IMPORTAÇÃO DA PLANILHA HISTÓRICA');
    console.log('  Arquivo :', path.resolve(arquivo));
    console.log('  Banco   :', process.env.DATABASE_NAME, '@', process.env.DATABASE_HOST + ':' + process.env.DATABASE_PORT);
    console.log('────────────────────────────────────────────────────────');

    if (!confirmou) {
        console.error('\n⚠️  Operação DESTRUTIVA (limpa o banco antes de importar).');
        console.error('   Confira se o banco acima é o de TESTE e rode de novo com --confirmar.\n');
        process.exit(1);
    }

    const wb = XLSX.readFile(arquivo, { cellDates: true });

    const linhasClientes = lerAba(wb, 'Clientes');
    const linhasEncomenda = lerAba(wb, 'Encomenda');
    const linhasPagamento = lerAba(wb, 'Pagamento');
    const linhasEntregas = lerAba(wb, 'Entregas');

    // Cabeçalhos de variedade (lidos dinamicamente das colunas das abas).
    const headerEnc = linhasEncomenda[0];
    const headerEnt = linhasEntregas[0];
    const variedadesEnc = headerEnc.slice(3, 12).map((v) => String(v).trim()); // cols 3..11
    // Entregas: variedades nas cols 4..12, mesma ordem; mapeadas por nome.
    const variedadesEnt = headerEnt.slice(4, 13).map((v) => String(v).trim());

    // ── 1. Limpeza (ordem FK-safe) ──────────────────────────────────────────
    console.log('\n[1/8] Limpando dados anteriores...');
    await prisma.itens_entrega.deleteMany();
    await prisma.itens_pedido.deleteMany();
    await prisma.entregas.deleteMany();
    await prisma.cheques.deleteMany();
    await prisma.pagamentos.deleteMany();
    await prisma.pedidos.deleteMany();
    await prisma.clientes.deleteMany({ where: { id: { not: 1 } } });

    // ── 2. Catálogos: produtos, temporada, conta "Caixa" ────────────────────
    console.log('[2/8] Garantindo produtos, temporada e conta "Caixa"...');
    const produtoIdPorVariedade = {};
    for (const variedade of variedadesEnc) {
        const nome = PREFIXO_PRODUTO + variedade;
        let prod = await prisma.produtos.findFirst({ where: { nome } });
        if (!prod) {
            prod = await prisma.produtos.create({ data: { nome, preco: PRECO_PADRAO, ativo: true } });
        }
        produtoIdPorVariedade[variedade] = prod.id;
    }

    await prisma.temporadas.upsert({
        where: { ano: TEMPORADA_ANO },
        update: {},
        create: { ano: TEMPORADA_ANO, ativo: true },
    });

    const contaCaixa = await prisma.contas.findFirst({ where: { nome: 'Caixa' } });
    if (!contaCaixa) await prisma.contas.create({ data: { nome: 'Caixa' } });

    // ── 3. Clientes (mapa n° → id) ──────────────────────────────────────────
    console.log('[3/8] Importando clientes...');
    const clienteIdPorN = {};
    let truncados = 0;
    for (let i = 1; i < linhasClientes.length; i++) {
        const r = linhasClientes[i];
        const n = num(r[0]);
        if (n === null) continue;
        const { estado, logradouro, truncou } = separarEndereco(r[5]);
        if (truncou) truncados++;
        const cli = await prisma.clientes.create({
            data: {
                cpf_cnpj: texto(r[1]),
                nome: texto(r[2]) || 'Sem nome',
                telefone_1: texto(r[3]),
                telefone_2: texto(r[4]),
                logradouro,
                estado,
                ativo: true,
            },
        });
        clienteIdPorN[n] = cli.id;
    }
    if (truncados) console.log(`      (${truncados} endereço(s) truncado(s) em ${MAX_LOGRADOURO} caracteres)`);

    // ── 4. Pré-índice de datas por n° (1ª mov. histórica) ───────────────────
    console.log('[4/8] Indexando datas históricas...');
    const minPagamentoPorN = {};
    const minEntregaPorN = {};
    for (let i = 1; i < linhasPagamento.length; i++) {
        const r = linhasPagamento[i];
        const n = num(r[1]);
        const d = comoData(r[4]);
        if (n === null || !d) continue;
        if (!minPagamentoPorN[n] || d < minPagamentoPorN[n]) minPagamentoPorN[n] = d;
    }
    for (let i = 1; i < linhasEntregas.length; i++) {
        const r = linhasEntregas[i];
        const n = num(r[1]);
        const d = comoData(r[3]);
        if (n === null || !d) continue;
        if (!minEntregaPorN[n] || d < minEntregaPorN[n]) minEntregaPorN[n] = d;
    }

    // ── 5. Pedidos + itens_pedido (mapa n° → pedido.id) ─────────────────────
    console.log('[5/8] Importando pedidos...');
    const pedidoIdPorN = {};
    for (let i = 1; i < linhasEncomenda.length; i++) {
        const r = linhasEncomenda[i];
        const n = num(r[1]);
        if (n === null) continue; // linha de totais vazia
        const clienteId = clienteIdPorN[n];
        if (!clienteId) {
            console.warn(`      ⚠️  Pedido n°${n} sem cliente correspondente — pulado.`);
            continue;
        }

        const desconto = num(r[14]) || 0;
        const valorFinal = num(r[15]);
        const ajuste = desconto > 0 ? -desconto : null;
        const dataPedido = minPagamentoPorN[n] || minEntregaPorN[n] || DATA_PADRAO_PEDIDO;

        const itens = [];
        for (let c = 0; c < variedadesEnc.length; c++) {
            const quantidade = qtd(r[3 + c]);
            if (quantidade > 0) {
                itens.push({
                    produto_id: produtoIdPorVariedade[variedadesEnc[c]],
                    quantidade,
                    valor_unitario: PRECO_PADRAO,
                });
            }
        }

        const pedido = await prisma.pedidos.create({
            data: {
                cliente_id: clienteId,
                valor_total: valorFinal,
                ajuste,
                status_geral: 'Ativa',
                ativo: true,
                temporada_ano: TEMPORADA_ANO,
                numero_temporada: n,
                data_pedido: dataPedido,
                criado_em: dataPedido,
                itens_pedido: { create: itens },
            },
        });
        pedidoIdPorN[n] = pedido.id;
    }

    // ── 6. Pagamentos (+ cheque depositado quando forma = Cheque) ───────────
    console.log('[6/8] Importando pagamentos...');
    let pagOk = 0;
    const puladosSemValor = []; // linhas com n° válido mas sem valor (ex.: escambo "Troca" em kg)
    for (let i = 1; i < linhasPagamento.length; i++) {
        const r = linhasPagamento[i];
        const n = num(r[1]);
        if (n === null) continue;
        const pedidoId = pedidoIdPorN[n];
        if (!pedidoId) continue;

        const valorPago = num(r[7]);
        if (valorPago === null) {
            // valor_pago é NOT NULL no schema; sem valor não há como gravar.
            puladosSemValor.push({ n, forma: texto(r[6]), valor: texto(r[7]) });
            continue;
        }

        const forma = sanearForma(r[6]);
        const dataPag = comoData(r[4]);

        const data = {
            pedido_id: pedidoId,
            valor_pago: valorPago,
            data_pagamento: dataPag,
            forma_pagamento: forma,
            conta: sanearConta(r[5]),
            nome_pagador: texto(r[8]),
        };

        // Cheque histórico já compensado: cria 1 cheque depositado para contar como recebido.
        if (forma === 'Cheque') {
            data.cheques = {
                create: [{
                    valor: valorPago,
                    depositado: true,
                    data_deposito: dataPag,
                }],
            };
        }

        await prisma.pagamentos.create({ data });
        pagOk++;
    }
    if (puladosSemValor.length > 0) {
        console.log(`      ⚠️  ${puladosSemValor.length} pagamento(s) sem valor em R$ — NÃO importados (revisar manualmente):`);
        for (const p of puladosSemValor) {
            console.log(`         pedido 26-${p.n} | forma "${p.forma}" | valor planilha "${p.valor}"`);
        }
    }

    // ── 7. Entregas + itens_entrega ─────────────────────────────────────────
    console.log('[7/8] Importando entregas...');
    let entOk = 0;
    for (let i = 1; i < linhasEntregas.length; i++) {
        const r = linhasEntregas[i];
        const n = num(r[1]);
        if (n === null) continue;
        const pedidoId = pedidoIdPorN[n];
        if (!pedidoId) continue;

        const itens = [];
        for (let c = 0; c < variedadesEnt.length; c++) {
            const quantidade = qtd(r[4 + c]);
            if (quantidade > 0) {
                itens.push({
                    produto_id: produtoIdPorVariedade[variedadesEnt[c]],
                    quantidade,
                });
            }
        }
        if (itens.length === 0) continue; // entrega sem itens → ignora

        await prisma.entregas.create({
            data: {
                pedido_id: pedidoId,
                data_entrega: comoData(r[3]),
                local_entrega: texto(r[13]),
                status_entrega: 'Realizada',
                itens_entrega: { create: itens },
            },
        });
        entOk++;
    }

    // ── 8. Recalcular status de cada pedido ─────────────────────────────────
    console.log('[8/8] Recalculando status de pagamento e entrega...');
    const ids = Object.values(pedidoIdPorN);
    for (const id of ids) {
        await recalcularStatusPedido(id);
        await recalcularStatusEntrega(id);
    }

    // ── Resumo ──────────────────────────────────────────────────────────────
    const [nClientes, nPedidos, nPagamentos, nEntregas, nProdutos] = await Promise.all([
        prisma.clientes.count(),
        prisma.pedidos.count(),
        prisma.pagamentos.count(),
        prisma.entregas.count(),
        prisma.produtos.count(),
    ]);

    console.log('\n✓ Importação concluída.');
    console.log('  produtos   :', nProdutos);
    console.log('  clientes   :', nClientes, '(inclui Consumidor id=1)');
    console.log('  pedidos    :', nPedidos);
    console.log('  pagamentos :', nPagamentos, `(${pagOk} importados)`);
    console.log('  entregas   :', nEntregas, `(${entOk} importadas)`);
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error('\n✗ Erro na importação:', e);
        process.exit(1);
    });
