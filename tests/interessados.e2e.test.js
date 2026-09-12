// e2e — lista de interessados: cadastro de cliente + mudas de interesse
// (sem valor, só produto+quantidade), edição, exclusão (soft-delete) e listagem.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente, marcador } = require('./helpers');

let amb;
let produtoId;

before(async () => {
    amb = await criarAmbiente();
    await amb.login();
    const produto = await amb.criarProduto();
    produtoId = produto.id;
});

after(async () => {
    await amb.encerrar();
});

test('criar interessado exige cliente_id e itens', async () => {
    const semCliente = await amb.api('POST', '/api/interessados', {
        body: { itens: [{ produto_id: produtoId, quantidade: 3 }] },
    });
    assert.equal(semCliente.status, 400);

    const semItens = await amb.api('POST', '/api/interessados', {
        body: { cliente_id: 1, itens: [] },
    });
    assert.equal(semItens.status, 400);
});

test('criar e buscar interessado traz cliente e itens com nome do produto, sem valor', async () => {
    const cliente = await amb.criarCliente();
    const interessadoId = await amb.criarInteressado({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoId, quantidade: 5 }],
    });

    const res = await amb.api('GET', `/api/interessados/${interessadoId}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.clientes?.id, cliente.id);
    assert.equal(res.body.itens_interesse.length, 1);
    assert.equal(res.body.itens_interesse[0].quantidade, 5);
    assert.ok(res.body.itens_interesse[0].produtos?.nome, 'item sem nome do produto');
    assert.equal(res.body.itens_interesse[0].valor_unitario, undefined, 'interessado não deveria ter valor');
});

test('editar interessado com itens substitui os itens', async () => {
    const interessadoId = await amb.criarInteressado({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2 }],
    });

    const outroProduto = await amb.criarProduto();
    const upd = await amb.api('PUT', `/api/interessados/${interessadoId}`, {
        body: { itens: [{ produto_id: outroProduto.id, quantidade: 7 }] },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.equal(upd.body.itens_interesse.length, 1);
    assert.equal(upd.body.itens_interesse[0].quantidade, 7);
    assert.equal(upd.body.itens_interesse[0].produto_id, outroProduto.id);

    const res = await amb.api('GET', `/api/interessados/${interessadoId}`);
    assert.equal(res.body.itens_interesse.length, 1, 'itens antigos não foram substituídos');
});

test('editar interessado sem itens mantém os itens e permite trocar o cliente/observações', async () => {
    const outroCliente = await amb.criarCliente();
    const interessadoId = await amb.criarInteressado({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2 }],
    });

    const upd = await amb.api('PUT', `/api/interessados/${interessadoId}`, {
        body: { cliente_id: outroCliente.id, observacoes: 'ligar semana que vem' },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.equal(upd.body.clientes.id, outroCliente.id);
    assert.equal(upd.body.observacoes, 'ligar semana que vem');
    assert.equal(upd.body.itens_interesse.length, 1, 'itens sumiram numa edição que não mexeu neles');
});

test('listagem filtra por nome do cliente', async () => {
    const nomeUnico = marcador('interessado');
    const cliente = await amb.criarCliente({ nome: nomeUnico });
    const interessadoId = await amb.criarInteressado({
        cliente_id: cliente.id,
        itens: [{ produto_id: produtoId, quantidade: 1 }],
    });

    const encontrado = await amb.api('GET', `/api/interessados?cliente=${encodeURIComponent(nomeUnico)}`);
    assert.ok(encontrado.body.some((i) => i.id === interessadoId));

    const naoEncontrado = await amb.api('GET', '/api/interessados?cliente=__nome_que_nao_existe__');
    assert.ok(!naoEncontrado.body.some((i) => i.id === interessadoId));
});

test('soft-delete some da consulta', async () => {
    const interessadoId = await amb.criarInteressado({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1 }],
    });

    const del = await amb.api('DELETE', `/api/interessados/${interessadoId}`);
    assert.ok(del.status === 200 || del.status === 204, `delete: ${del.status}`);

    const get = await amb.api('GET', `/api/interessados/${interessadoId}`);
    assert.equal(get.status, 404);
});
