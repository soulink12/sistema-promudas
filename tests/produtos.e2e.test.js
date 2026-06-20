// e2e — CRUD de produtos (criar, validação, listar todos, atualizar, soft-delete).

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

test('criar sem nome ou preço retorna 400', async () => {
    const semNome = await amb.api('POST', '/api/produtos', { body: { preco: 10 } });
    assert.equal(semNome.status, 400);

    const semPreco = await amb.api('POST', '/api/produtos', { body: { nome: marcador('prod') } });
    assert.equal(semPreco.status, 400);
});

test('cria, aparece na listagem, atualiza e soft-delete (continua na listagem do back)', async () => {
    const nome = marcador('prod');
    const criar = await amb.api('POST', '/api/produtos', { body: { nome, preco: 30 } });
    assert.equal(criar.status, 201, JSON.stringify(criar.body));
    const id = criar.body.id;
    assert.ok(id);
    amb.registrar.produto(id);

    const lista = await amb.api('GET', '/api/produtos');
    assert.equal(lista.status, 200);
    assert.ok(lista.body.some((p) => p.id === id), 'produto não apareceu na listagem');

    // Atualiza nome e preço.
    const upd = await amb.api('PUT', `/api/produtos/${id}`, {
        body: { nome: `${nome}_v2`, preco: 45 },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));

    // Soft-delete → ativo=false, mas o backend continua retornando (front filtra).
    const del = await amb.api('DELETE', `/api/produtos/${id}`);
    assert.ok(del.status === 200 || del.status === 204, `delete: ${del.status}`);

    const lista2 = await amb.api('GET', '/api/produtos');
    const achado = lista2.body.find((p) => p.id === id);
    assert.ok(achado, 'produto inativo deveria continuar na listagem do backend');
    assert.equal(achado.ativo, false);
});
