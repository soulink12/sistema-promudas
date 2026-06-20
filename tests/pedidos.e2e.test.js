// e2e — pedidos: criação/validação, leitura completa, edição que recalcula total,
// geração de crédito do cliente e soft-delete.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente } = require('./helpers');

let amb;
let produtoId;

before(async () => {
    amb = await criarAmbiente();
    await amb.login();
    const produto = await amb.criarProduto({ preco: 50 });
    produtoId = produto.id;
});

after(async () => {
    await amb.encerrar();
});

test('criar pedido exige cliente_id e itens', async () => {
    const semCliente = await amb.api('POST', '/api/pedidos', {
        body: { itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }] },
    });
    assert.equal(semCliente.status, 400);

    const semItens = await amb.api('POST', '/api/pedidos', {
        body: { cliente_id: 1, itens: [] },
    });
    assert.equal(semItens.status, 400);
});

test('buscar pedido traz itens com nome do produto e flag de pagamento posterior', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });

    await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 50,
            forma_pagamento: 'Crediário',
            data_pagamento: new Date().toISOString(),
        },
    });

    const res = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(res.status, 200);
    assert.ok(res.body.itens_pedido[0].produtos?.nome, 'item sem nome do produto');
    const credi = res.body.pagamentos.find((p) => p.forma_pagamento === 'Crediário');
    assert.equal(credi.pagamento_posterior, true);
});

test('editar pedido recalcula o valor_total', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });

    const upd = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 3, valor_unitario: 50 }] },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));

    const res = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(Number(res.body.valor_total), 150);
});

test('reduzir um pedido já pago gera crédito para o cliente e status Crédito', async () => {
    const cliente = await amb.criarCliente();

    const saldoInicial = Number(
        (await amb.api('GET', `/api/clientes/${cliente.id}`)).body.saldo_credito ?? 0,
    );

    const pedidoId = await amb.criarPedido({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }], // total 100
    });

    // Paga 100 (real) → Pago.
    await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 100,
            forma_pagamento: 'PIX',
            data_pagamento: new Date().toISOString(),
        },
    });

    // Edita para 1 item (total 50) → sobra 50 vira crédito do cliente.
    const upd = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }] },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.ok(Math.abs(Number(upd.body.creditoGerado) - 50) < 0.01, 'creditoGerado != 50');

    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(ped.body.status_pagamento, 'Crédito');

    const saldoFinal = Number(
        (await amb.api('GET', `/api/clientes/${cliente.id}`)).body.saldo_credito ?? 0,
    );
    assert.ok(Math.abs((saldoFinal - saldoInicial) - 50) < 0.01,
        `saldo_credito não subiu 50 (de ${saldoInicial} para ${saldoFinal})`);
});

test('soft-delete some da consulta e bloqueia novo pagamento', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });

    const del = await amb.api('DELETE', `/api/pedidos/${pedidoId}`);
    assert.ok(del.status === 200 || del.status === 204, `delete: ${del.status}`);

    // buscarPedido filtra ativo=true → 404.
    const get = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(get.status, 404);

    // Pagamento em pedido inativo é bloqueado.
    const pg = await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 10,
            forma_pagamento: 'PIX',
            data_pagamento: new Date().toISOString(),
        },
    });
    assert.equal(pg.status, 400);
});
