// e2e — CRUD de clientes (criar, buscar, listar, busca, atualizar, soft-delete).

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

test('cria, busca por id e lista com filtro de busca', async () => {
    const nome = marcador('cli');
    const cpf = `999${Date.now()}`.slice(0, 14);

    const criar = await amb.api('POST', '/api/clientes', {
        body: { nome, cpf_cnpj: cpf, telefone_1: '11999990000' },
    });
    assert.equal(criar.status, 201, JSON.stringify(criar.body));
    const id = criar.body.id ?? criar.body.data?.id ?? criar.body;
    assert.ok(id, `sem id na resposta: ${JSON.stringify(criar.body)}`);
    amb.registrar.cliente(id);

    // Busca por id.
    const porId = await amb.api('GET', `/api/clientes/${id}`);
    assert.equal(porId.status, 200);
    assert.equal(porId.body.nome, nome);

    // Busca por texto (nome).
    const busca = await amb.api('GET', `/api/clientes?busca=${encodeURIComponent(nome)}`);
    assert.equal(busca.status, 200);
    assert.ok(
        busca.body.some((c) => c.id === id),
        'cliente não apareceu na busca por nome',
    );
});

test('atualiza e faz soft-delete (some da listagem com ativo)', async () => {
    const c = await amb.criarCliente({ telefone_1: '11888887777' });

    const upd = await amb.api('PUT', `/api/clientes/${c.id}`, {
        body: { nome: `${c.nome}_editado` },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));

    const conf = await amb.api('GET', `/api/clientes/${c.id}`);
    assert.match(conf.body.nome, /_editado$/);

    // Soft-delete.
    const del = await amb.api('DELETE', `/api/clientes/${c.id}`);
    assert.ok(del.status === 200 || del.status === 204, `delete: ${del.status}`);

    // Some da busca (que filtra ativo=true).
    const busca = await amb.api('GET', `/api/clientes?busca=${encodeURIComponent(c.nome)}`);
    assert.ok(
        !busca.body.some((x) => x.id === c.id),
        'cliente inativo não deveria aparecer na listagem',
    );
});
