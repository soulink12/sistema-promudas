// e2e — entregas: saldo por produto, status (Parcial/Entregue/Pendente),
// edição com revalidação, exclusão e listagem enriquecida.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente } = require('./helpers');

let amb;
let produtoA;
let produtoB;

before(async () => {
    amb = await criarAmbiente();
    await amb.login();
    produtoA = (await amb.criarProduto({ preco: 10 })).id;
    produtoB = (await amb.criarProduto({ preco: 10 })).id;
});

after(async () => {
    await amb.encerrar();
});

async function statusEntrega(pedidoId) {
    const res = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    return res.body.status_entrega;
}

function entregar(pedidoId, itens) {
    return amb.api('POST', '/api/entregas', {
        body: { pedido_id: pedidoId, local_entrega: 'Paraíso', itens },
    });
}

test('entrega parcial → Parcial; completar → Entregue', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoA, quantidade: 5, valor_unitario: 10 }],
    });
    assert.equal(await statusEntrega(pedidoId), 'Pendente');

    let e = await entregar(pedidoId, [{ produto_id: produtoA, quantidade: 2 }]);
    assert.equal(e.status, 201, JSON.stringify(e.body));
    assert.equal(await statusEntrega(pedidoId), 'Parcial');

    e = await entregar(pedidoId, [{ produto_id: produtoA, quantidade: 3 }]);
    assert.equal(e.status, 201, JSON.stringify(e.body));
    assert.equal(await statusEntrega(pedidoId), 'Entregue');
});

test('entrega que excede o saldo do produto é rejeitada', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoA, quantidade: 5, valor_unitario: 10 }],
    });
    await entregar(pedidoId, [{ produto_id: produtoA, quantidade: 2 }]);

    const e = await entregar(pedidoId, [{ produto_id: produtoA, quantidade: 5 }]); // saldo é 3
    assert.equal(e.status, 400, JSON.stringify(e.body));
    assert.match(e.body.erro, /saldo/i);
});

test('entrega de produto fora do pedido é rejeitada', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoA, quantidade: 2, valor_unitario: 10 }],
    });
    const e = await entregar(pedidoId, [{ produto_id: produtoB, quantidade: 1 }]);
    assert.equal(e.status, 400, JSON.stringify(e.body));
    assert.match(e.body.erro, /faz parte/i);
});

test('editar entrega revalida saldo e recalcula status; excluir volta a Pendente', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoA, quantidade: 5, valor_unitario: 10 }],
    });
    const criada = await entregar(pedidoId, [{ produto_id: produtoA, quantidade: 5 }]);
    const entregaId = criada.body.id;
    assert.equal(await statusEntrega(pedidoId), 'Entregue');

    // Reduz a entrega para 2 → status volta a Parcial.
    const upd = await amb.api('PUT', `/api/entregas/${entregaId}`, {
        body: { itens: [{ produto_id: produtoA, quantidade: 2 }] },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.equal(await statusEntrega(pedidoId), 'Parcial');

    // Exclui a entrega → volta a Pendente.
    const del = await amb.api('DELETE', `/api/entregas/${entregaId}`);
    assert.equal(del.status, 200, JSON.stringify(del.body));
    assert.equal(await statusEntrega(pedidoId), 'Pendente');
});

test('listar entregas inclui cliente e nome dos produtos', async () => {
    const cliente = await amb.criarCliente();
    const pedidoId = await amb.criarPedido({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoA, quantidade: 2, valor_unitario: 10 }],
    });
    await entregar(pedidoId, [{ produto_id: produtoA, quantidade: 1 }]);

    const res = await amb.api('GET', `/api/entregas?cliente=${encodeURIComponent(cliente.nome)}`);
    assert.equal(res.status, 200);
    const minha = res.body.find((e) => e.pedidos?.id === pedidoId);
    assert.ok(minha, 'entrega do pedido não encontrada na listagem filtrada');
    assert.equal(minha.pedidos.clientes.nome, cliente.nome);
    assert.ok(minha.itens_entrega[0].produtos?.nome, 'item de entrega sem nome do produto');
});
