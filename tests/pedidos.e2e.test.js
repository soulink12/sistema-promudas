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

test('reeditar pedido já creditado não credita de novo, e voltar a subir estorna', async () => {
    const cliente = await amb.criarCliente();
    const saldo = async () => Number(
        (await amb.api('GET', `/api/clientes/${cliente.id}`)).body.saldo_credito ?? 0,
    );

    const saldoInicial = await saldo();

    const pedidoId = await amb.criarPedido({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }], // total 100
    });
    await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 100,
            forma_pagamento: 'PIX',
            data_pagamento: new Date().toISOString(),
        },
    });

    // 1ª edição: 100 → 50. A sobra de 50 vira crédito.
    const primeira = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }] },
    });
    assert.equal(primeira.status, 200, JSON.stringify(primeira.body));
    assert.ok(Math.abs((await saldo()) - saldoInicial - 50) < 0.01, 'primeira edição não creditou 50');

    // 2ª edição sem mudar o total: a sobra continua a mesma, então nada é
    // creditado de novo (antes, cada reedição creditava outros 50).
    const segunda = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }] },
    });
    assert.equal(segunda.status, 200, JSON.stringify(segunda.body));
    assert.ok(Math.abs(Number(segunda.body.creditoGerado)) < 0.01,
        `reedição creditou de novo: ${segunda.body.creditoGerado}`);
    assert.ok(Math.abs((await saldo()) - saldoInicial - 50) < 0.01,
        'saldo mudou numa reedição que não alterou o total');

    // 3ª edição: volta para 100. A sobra some, então o crédito é estornado.
    const terceira = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }] },
    });
    assert.equal(terceira.status, 200, JSON.stringify(terceira.body));
    assert.ok(Math.abs((await saldo()) - saldoInicial) < 0.01,
        'crédito não foi estornado ao pedido voltar ao valor original');
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

test('pedido pago e entregue bloqueia edição de itens, mas não de data', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }], // total 100
    });

    await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 100,
            forma_pagamento: 'PIX',
            data_pagamento: new Date().toISOString(),
        },
    });
    await amb.api('POST', '/api/entregas', {
        body: {
            pedido_id: pedidoId,
            local_entrega: 'Paraíso',
            itens: [{ produto_id: produtoId, quantidade: 2 }],
        },
    });

    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(ped.body.status_pagamento, 'Pago');
    assert.equal(ped.body.status_entrega, 'Entregue');

    const updItens = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 3, valor_unitario: 50 }] },
    });
    assert.equal(updItens.status, 400);
    assert.ok(updItens.body.erro, 'esperava mensagem de erro de negócio');

    // Edição de metadados (sem `itens`) continua liberada mesmo com o pedido fechado.
    const updData = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { data_pedido: new Date().toISOString() },
    });
    assert.equal(updData.status, 200, JSON.stringify(updData.body));
});

test('busca por número do pedido (AA-N, só o número da temporada, e #id)', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });

    // Ano improvável de colidir com temporadas reais — dá numeração previsível (1º pedido da "safra").
    const setTemporada = await amb.api('PUT', `/api/pedidos/${pedidoId}`, {
        body: { temporada_ano: 2099 },
    });
    assert.equal(setTemporada.status, 200, JSON.stringify(setTemporada.body));

    const resAaN = await amb.api('GET', '/api/pedidos?numero=99-1');
    assert.ok(resAaN.body.some((p) => p.id === pedidoId), 'não achou pelo formato AA-N');
    assert.ok(!resAaN.body.some((p) => p.id !== pedidoId && p.temporada_ano === 2099),
        'formato AA-N trouxe pedido de outra numeração');

    // Só o número da temporada, sem precisar informar a safra.
    const resSoNumero = await amb.api('GET', '/api/pedidos?numero=1');
    assert.ok(resSoNumero.body.some((p) => p.id === pedidoId),
        'não achou só pelo número da temporada, sem a safra');

    const resHash = await amb.api('GET', `/api/pedidos?numero=%23${pedidoId}`);
    assert.ok(resHash.body.some((p) => p.id === pedidoId), 'não achou pelo formato #id');
});

test('filtros de temporada e forma de pagamento', async () => {
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 3, valor_unitario: 50 }], // total 150
    });
    await amb.api('PUT', `/api/pedidos/${pedidoId}`, { body: { temporada_ano: 2098 } });
    await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 50,
            forma_pagamento: 'PIX',
            data_pagamento: new Date().toISOString(),
        },
    });

    const porTemporada = await amb.api('GET', '/api/pedidos?temporadaAno=2098');
    assert.ok(porTemporada.body.some((p) => p.id === pedidoId), 'filtro de temporada não achou o pedido');

    const outraTemporada = await amb.api('GET', '/api/pedidos?temporadaAno=2097');
    assert.ok(!outraTemporada.body.some((p) => p.id === pedidoId), 'temporada errada não deveria trazer o pedido');

    const porForma = await amb.api('GET', '/api/pedidos?formaPagamento=PIX');
    assert.ok(porForma.body.some((p) => p.id === pedidoId), 'filtro de forma de pagamento não achou o pedido');

    const outraForma = await amb.api('GET', '/api/pedidos?formaPagamento=Dinheiro');
    assert.ok(!outraForma.body.some((p) => p.id === pedidoId), 'forma errada não deveria trazer o pedido');
});

test('filtro por clienteId não mistura pedidos de clientes com nome parecido', async () => {
    const ana = await amb.criarCliente({ nome: 'Ana Teste Filtro' });
    const anaMaria = await amb.criarCliente({ nome: 'Ana Teste Filtro Maria' });
    amb.registrar.cliente(ana.id);
    amb.registrar.cliente(anaMaria.id);

    const pedidoAna = await amb.criarPedido({
        cliente_id: ana.id,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });
    await amb.criarPedido({
        cliente_id: anaMaria.id,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });

    // Por nome, o `contains` do backend traz os dois.
    const porNome = await amb.api('GET', '/api/pedidos?cliente=Ana Teste Filtro');
    assert.ok(porNome.body.length >= 2, 'o filtro por nome deveria trazer os homônimos');

    // Por id, só o pedido do cliente certo.
    const porId = await amb.api('GET', `/api/pedidos?clienteId=${ana.id}`);
    assert.equal(porId.status, 200, JSON.stringify(porId.body));
    assert.equal(porId.body.length, 1, 'filtro por id trouxe pedido de outro cliente');
    assert.equal(porId.body[0].id, pedidoAna);
});
