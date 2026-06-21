// e2e — fluxo financeiro de pagamentos (status, edição, exclusão, nota fiscal, conta pendente).
// Ver tests/helpers.js para a infra (app em porta efêmera, login, limpeza autolimpante).

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

// Cria um pedido total 100 (Consumidor id=1, produto descartável × 2 a 50).
async function novoPedido() {
    return amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });
}

async function statusPagamento(pedidoId) {
    const res = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(res.status, 200, `buscar pedido: ${JSON.stringify(res.body)}`);
    return res.body.status_pagamento;
}

function pagar(pedidoId, valor, forma = 'PIX', extra = {}) {
    return amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: valor,
            forma_pagamento: forma,
            data_pagamento: new Date().toISOString(),
            ...extra,
        },
    });
}

test('pagamento parcial leva a Parcial e depois a Pago', async () => {
    const pedidoId = await novoPedido();
    assert.equal(await statusPagamento(pedidoId), 'Pendente');

    let pg = await pagar(pedidoId, 40);
    assert.equal(pg.status, 201, `1º pagamento: ${JSON.stringify(pg.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Parcial');

    pg = await pagar(pedidoId, 60);
    assert.equal(pg.status, 201, `2º pagamento: ${JSON.stringify(pg.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Pago');
});

test('pagamento que excede o total é rejeitado e não altera o status', async () => {
    const pedidoId = await novoPedido();
    const pg = await pagar(pedidoId, 150);
    assert.equal(pg.status, 400, `esperava 400: ${JSON.stringify(pg.body)}`);
    assert.match(pg.body.erro, /excede/i);
    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});

test('crediário (pagamento posterior) não conta como recebido', async () => {
    const pedidoId = await novoPedido();
    const pg = await pagar(pedidoId, 100, 'Crediário');
    assert.equal(pg.status, 201, `crediário: ${JSON.stringify(pg.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});

test('data de pagamento realmente inválida retorna 400 (não 500)', async () => {
    const pedidoId = await novoPedido();
    const pg = await pagar(pedidoId, 50, 'PIX', { data_pagamento: 'data-ruim' });
    assert.equal(pg.status, 400, `esperava 400: ${JSON.stringify(pg.body)}`);
    assert.match(pg.body.erro, /data inválida/i);
    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});

test('aceita data ISO sem "Z" e com microssegundos (formato do Dart)', async () => {
    const pedidoId = await novoPedido();
    // DateTime.toIso8601String() do Dart: microssegundos e sem fuso. Antes
    // estourava 500 no Prisma; agora é normalizada e aceita.
    const pg = await pagar(pedidoId, 100, 'PIX',
        { data_pagamento: '2026-06-20T16:55:31.123456' });
    assert.equal(pg.status, 201, `esperava 201: ${JSON.stringify(pg.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Pago');
});

test('editar pagamento recalcula o status (Pago → Parcial) e respeita o saldo', async () => {
    const pedidoId = await novoPedido();
    const pg = await pagar(pedidoId, 100);
    assert.equal(pg.status, 201);
    const pagamentoId = pg.body.id;
    assert.equal(await statusPagamento(pedidoId), 'Pago');

    // Editar acima do saldo permitido (100) é rejeitado.
    const excede = await amb.api('PUT', `/api/pagamentos/${pagamentoId}`, {
        body: { valor_pago: 150 },
    });
    assert.equal(excede.status, 400, `esperava 400: ${JSON.stringify(excede.body)}`);
    assert.match(excede.body.erro, /excede/i);

    // Reduzir o valor recalcula para Parcial.
    const ok = await amb.api('PUT', `/api/pagamentos/${pagamentoId}`, {
        body: { valor_pago: 40 },
    });
    assert.equal(ok.status, 200, `editar: ${JSON.stringify(ok.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Parcial');
});

test('excluir pagamento volta o status para Pendente', async () => {
    const pedidoId = await novoPedido();
    const pg = await pagar(pedidoId, 100);
    const pagamentoId = pg.body.id;
    assert.equal(await statusPagamento(pedidoId), 'Pago');

    const del = await amb.api('DELETE', `/api/pagamentos/${pagamentoId}`);
    assert.equal(del.status, 200, `excluir: ${JSON.stringify(del.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});

test('nota fiscal é persistida e lida no pedido', async () => {
    const pedidoId = await novoPedido();
    const pg = await pagar(pedidoId, 100);
    const pagamentoId = pg.body.id;

    const put = await amb.api('PUT', `/api/pagamentos/${pagamentoId}`, {
        body: {
            status_nota: 'Emitida',
            numero_nota: '12345',
            data_emissao_nota: '2026-06-20T00:00:00.000Z',
        },
    });
    assert.equal(put.status, 200, `nota: ${JSON.stringify(put.body)}`);

    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    const pago = ped.body.pagamentos.find((p) => p.id === pagamentoId);
    assert.ok(pago, 'pagamento não encontrado no pedido');
    assert.equal(pago.status_nota, 'Emitida');
    assert.equal(pago.numero_nota, '12345');
});

test('pagamento em Dinheiro fica sem conta e some após definir a conta', async () => {
    const pedidoId = await novoPedido();
    // Dinheiro = conta_posterior (não escolhe conta no PDV) → fica pendente de conta.
    const pg = await pagar(pedidoId, 100, 'Dinheiro');
    assert.equal(pg.status, 201, `dinheiro: ${JSON.stringify(pg.body)}`);
    const pagamentoId = pg.body.id;

    const antes = await amb.api('GET', '/api/pagamentos/pendentes-conta');
    assert.ok(
        antes.body.some((p) => p.id === pagamentoId),
        'pagamento em dinheiro deveria estar pendente de conta',
    );

    const def = await amb.api('PUT', `/api/pagamentos/${pagamentoId}`, {
        body: { conta: 'Lucas' },
    });
    assert.equal(def.status, 200, `definir conta: ${JSON.stringify(def.body)}`);

    const depois = await amb.api('GET', '/api/pagamentos/pendentes-conta');
    assert.ok(
        !depois.body.some((p) => p.id === pagamentoId),
        'pagamento não deveria mais estar pendente de conta',
    );
});
