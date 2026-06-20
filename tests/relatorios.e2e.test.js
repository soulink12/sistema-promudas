// e2e — relatórios (pagamentos e pedidos) + geração de PDFs.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente } = require('./helpers');

let amb;
let produtoId;
let cliente;
let pedidoPagoId;

before(async () => {
    amb = await criarAmbiente();
    await amb.login();
    produtoId = (await amb.criarProduto({ preco: 50 })).id;
    cliente = await amb.criarCliente();

    // Pedido 1: total 100, pago (PIX) → Pago.
    pedidoPagoId = await amb.criarPedido({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });
    await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoPagoId,
            valor_pago: 100,
            forma_pagamento: 'PIX',
            data_pagamento: new Date().toISOString(),
        },
    });

    // Pedido 2: total 50, sem pagamento → Pendente.
    await amb.criarPedido({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });
});

after(async () => {
    await amb.encerrar();
});

test('relatório de pedidos filtra por cliente e resume por status', async () => {
    const res = await amb.api('GET', `/api/relatorios/pedidos?clienteId=${cliente.id}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.resumo.total, 2, 'deveria ter exatamente 2 pedidos do cliente');
    assert.ok(Math.abs(res.body.resumo.valorTotal - 150) < 0.01, 'valorTotal != 150');
    assert.equal(res.body.resumo.porStatusPagamento.Pago, 1);
    assert.equal(res.body.resumo.porStatusPagamento.Pendente, 1);
    assert.equal(res.body.lista.length, 2);
});

test('relatório de pagamentos é consistente e filtra por forma', async () => {
    const geral = await amb.api('GET', '/api/relatorios/pagamentos');
    assert.equal(geral.status, 200);
    const somaItens = geral.body.resultado.reduce((s, r) => s + r.total, 0);
    assert.ok(Math.abs(somaItens - geral.body.totalGeral) < 0.01,
        'totalGeral diverge da soma dos grupos');

    const porForma = await amb.api('GET', '/api/relatorios/pagamentos?forma=PIX');
    assert.equal(porForma.status, 200);
    assert.ok(
        porForma.body.resultado.every((r) => r.forma_pagamento === 'PIX'),
        'filtro por forma trouxe outras formas',
    );
});

test('gera PDFs válidos (recibo do pedido e relatórios)', async () => {
    const ehPdf = (r) => r.status === 200 && r.bytes.subarray(0, 5).toString('ascii') === '%PDF-';

    const recibo = await amb.apiBytes('GET', `/api/pedidos/${pedidoPagoId}/pdf`);
    assert.ok(ehPdf(recibo), `recibo não é PDF (status ${recibo.status})`);

    const relPag = await amb.apiBytes('GET', '/api/relatorios/pagamentos/pdf');
    assert.ok(ehPdf(relPag), `relatório de pagamentos não é PDF (status ${relPag.status})`);

    const relPed = await amb.apiBytes('GET', '/api/relatorios/pedidos/pdf');
    assert.ok(ehPdf(relPed), `relatório de pedidos não é PDF (status ${relPed.status})`);
});
