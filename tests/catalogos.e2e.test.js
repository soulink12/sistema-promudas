// e2e — catálogos: formas de pagamento (CRUD + soft-delete), contas e locais de entrega.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente, marcador } = require('./helpers');

let amb;

before(async () => {
    amb = await criarAmbiente();
    await amb.login();
});

after(async () => {
    await amb.encerrar();
});

test('formas de pagamento: criar, listar, atualizar e soft-delete', async () => {
    const nome = marcador('forma');
    const criar = await amb.api('POST', '/api/formas-pagamento', {
        body: { nome, pagamento_posterior: false, conta_posterior: true, parcelado_em_ate: 3 },
    });
    assert.equal(criar.status, 201, JSON.stringify(criar.body));
    const id = criar.body.id;
    assert.ok(id);
    amb.registrar.forma(id);
    assert.equal(criar.body.conta_posterior, true);
    assert.equal(criar.body.parcelado_em_ate, 3);

    // Lista (ordenada por nome, inclui ativos e inativos).
    const lista = await amb.api('GET', '/api/formas-pagamento');
    assert.ok(lista.body.some((f) => f.id === id), 'forma criada não apareceu na listagem');

    // Atualiza.
    const upd = await amb.api('PUT', `/api/formas-pagamento/${id}`, {
        body: { nome: `${nome}_v2`, parcelado_em_ate: 6 },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.equal(upd.body.parcelado_em_ate, 6);

    // Soft-delete.
    const del = await amb.api('DELETE', `/api/formas-pagamento/${id}`);
    assert.equal(del.status, 204);
    const lista2 = await amb.api('GET', '/api/formas-pagamento');
    assert.equal(lista2.body.find((f) => f.id === id).ativo, false);
});

test('forma de pagamento já usada não pode ser renomeada, mas segue editável', async () => {
    const nome = marcador('forma_usada');
    const criar = await amb.api('POST', '/api/formas-pagamento', {
        body: { nome, conta_posterior: true, parcelado_em_ate: 1 },
    });
    assert.equal(criar.status, 201, JSON.stringify(criar.body));
    const id = criar.body.id;
    amb.registrar.forma(id);

    // Antes de ser usada, renomear é permitido.
    const renomeioLivre = await amb.api('PUT', `/api/formas-pagamento/${id}`, {
        body: { nome: `${nome}_ok` },
    });
    assert.equal(renomeioLivre.status, 200, JSON.stringify(renomeioLivre.body));

    // Usa a forma num pagamento real.
    const produto = await amb.criarProduto({ preco: 50 });
    const pedidoId = await amb.criarPedido({
        cliente_id: 1,
        itens: [{ produto_id: produto.id, quantidade: 1, valor_unitario: 50 }],
    });
    const pg = await amb.api('POST', '/api/pagamentos', {
        body: {
            pedido_id: pedidoId,
            valor_pago: 50,
            forma_pagamento: `${nome}_ok`,
            data_pagamento: new Date().toISOString(),
        },
    });
    assert.equal(pg.status, 201, JSON.stringify(pg.body));

    // Agora o rename é bloqueado — renomear reclassificaria o pagamento antigo.
    const renomeio = await amb.api('PUT', `/api/formas-pagamento/${id}`, {
        body: { nome: `${nome}_v3` },
    });
    assert.equal(renomeio.status, 400, JSON.stringify(renomeio.body));
    assert.match(renomeio.body.erro, /renomeada/i);

    // O nome continua o mesmo no banco.
    const lista = await amb.api('GET', '/api/formas-pagamento');
    assert.equal(lista.body.find((f) => f.id === id).nome, `${nome}_ok`);

    // Os outros campos seguem editáveis normalmente.
    const outroCampo = await amb.api('PUT', `/api/formas-pagamento/${id}`, {
        body: { parcelado_em_ate: 12 },
    });
    assert.equal(outroCampo.status, 200, JSON.stringify(outroCampo.body));
    assert.equal(outroCampo.body.parcelado_em_ate, 12);

    // Reenviar o MESMO nome não é considerado rename (o app manda o form inteiro).
    const mesmoNome = await amb.api('PUT', `/api/formas-pagamento/${id}`, {
        body: { nome: `${nome}_ok`, parcelado_em_ate: 6 },
    });
    assert.equal(mesmoNome.status, 200, JSON.stringify(mesmoNome.body));
});

test('atualizar forma inexistente retorna 404', async () => {
    const res = await amb.api('PUT', '/api/formas-pagamento/2000000000', {
        body: { nome: 'x' },
    });
    assert.equal(res.status, 404);
});

test('contas e locais de entrega retornam listas de ativos', async () => {
    const contas = await amb.api('GET', '/api/contas');
    assert.equal(contas.status, 200);
    assert.ok(Array.isArray(contas.body) && contas.body.length > 0, 'sem contas');
    assert.ok(contas.body[0].nome, 'conta sem nome');

    const locais = await amb.api('GET', '/api/locais-entrega');
    assert.equal(locais.status, 200);
    assert.ok(Array.isArray(locais.body) && locais.body.length > 0, 'sem locais');
    assert.ok(locais.body[0].nome, 'local sem nome');
});
