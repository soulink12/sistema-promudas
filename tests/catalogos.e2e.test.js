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
