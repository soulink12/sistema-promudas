// e2e — orçamentos: validação, edição (com e sem itens), aprovação (gera pedido
// de verdade) e recusa. Módulo introduzido na PR #2 e, até aqui, sem nenhum
// teste automatizado — cobre principalmente os bugs corrigidos depois do merge:
// atualizarOrcamento sem transação (perda de itens em falha parcial), resposta
// inconsistente do PUT sem `itens`, e aprovarOrcamento duplicando criarPedido.

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

test('criar orçamento exige cliente_id e itens', async () => {
    const semCliente = await amb.api('POST', '/api/orcamentos', {
        body: { itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }] },
    });
    assert.equal(semCliente.status, 400);

    const semItens = await amb.api('POST', '/api/orcamentos', {
        body: { cliente_id: 1, itens: [] },
    });
    assert.equal(semItens.status, 400);
});

test('buscar orçamento traz cliente e itens com nome do produto', async () => {
    const orcamentoId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });

    const res = await amb.api('GET', `/api/orcamentos/${orcamentoId}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'Pendente');
    assert.ok(res.body.clientes?.nome, 'orçamento sem cliente na resposta');
    assert.ok(res.body.itens_orcamento[0].produtos?.nome, 'item sem nome do produto');
});

test('editar orçamento com itens recalcula valor_total e substitui os itens', async () => {
    const orcamentoId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }], // total 100
    });

    const upd = await amb.api('PUT', `/api/orcamentos/${orcamentoId}`, {
        body: { itens: [{ produto_id: produtoId, quantidade: 3, valor_unitario: 50 }] }, // total 150
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.equal(Number(upd.body.valor_total), 150);
    // A resposta do PUT já vem no formato completo (clientes + itens_orcamento).
    assert.ok(upd.body.clientes?.nome, 'PUT com itens não devolveu clientes');
    assert.equal(upd.body.itens_orcamento.length, 1);

    const res = await amb.api('GET', `/api/orcamentos/${orcamentoId}`);
    assert.equal(Number(res.body.valor_total), 150);
    assert.equal(res.body.itens_orcamento.length, 1, 'itens antigos não foram substituídos');
});

test('editar orçamento sem itens mantém os itens e devolve o mesmo formato do GET', async () => {
    const orcamentoId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });

    const upd = await amb.api('PUT', `/api/orcamentos/${orcamentoId}`, {
        body: { observacoes: 'só uma nota' },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));
    assert.ok(upd.body.clientes?.nome, 'PUT sem itens não devolveu clientes');
    assert.ok(Array.isArray(upd.body.itens_orcamento), 'PUT sem itens não devolveu itens_orcamento');
    assert.equal(upd.body.itens_orcamento.length, 1, 'itens sumiram numa edição que não mexeu neles');
    assert.equal(upd.body.observacoes, 'só uma nota');
});

test('aprovar orçamento cria um pedido de verdade com os mesmos dados', async () => {
    const cliente = await amb.criarCliente();
    const orcamentoId = await amb.criarOrcamento({
        cliente_id: cliente.id,
        ajuste: -10,
        valor_total: 90, // 100 (itens) - 10 (ajuste)
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });

    const aprovado = await amb.api('POST', `/api/orcamentos/${orcamentoId}/aprovar`);
    assert.equal(aprovado.status, 200, JSON.stringify(aprovado.body));
    assert.equal(aprovado.body.status, 'Aprovado');
    assert.ok(aprovado.body.pedido_id, 'aprovação não vinculou um pedido_id');
    amb.registrar.pedido(aprovado.body.pedido_id);

    const pedido = await amb.api('GET', `/api/pedidos/${aprovado.body.pedido_id}`);
    assert.equal(pedido.status, 200);
    assert.equal(pedido.body.clientes.id, cliente.id);
    assert.equal(Number(pedido.body.valor_total), 90);
    assert.equal(pedido.body.itens_pedido.length, 1);
    assert.equal(pedido.body.itens_pedido[0].quantidade, 2);
    assert.equal(pedido.body.status_geral, 'Ativa');
    assert.equal(pedido.body.status_pagamento, 'Pendente');

    // Orçamento já decidido não pode mais ser aprovado, recusado ou editado.
    const reAprovar = await amb.api('POST', `/api/orcamentos/${orcamentoId}/aprovar`);
    assert.equal(reAprovar.status, 400);

    const recusar = await amb.api('POST', `/api/orcamentos/${orcamentoId}/recusar`);
    assert.equal(recusar.status, 400);

    const editar = await amb.api('PUT', `/api/orcamentos/${orcamentoId}`, {
        body: { observacoes: 'tentando editar depois de aprovado' },
    });
    assert.equal(editar.status, 400);
});

test('recusar orçamento muda o status para Rejeitado sem criar pedido', async () => {
    const orcamentoId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });

    const recusado = await amb.api('POST', `/api/orcamentos/${orcamentoId}/recusar`);
    assert.equal(recusado.status, 200, JSON.stringify(recusado.body));
    assert.equal(recusado.body.status, 'Rejeitado');
    assert.equal(recusado.body.pedido_id, null);

    const reRecusar = await amb.api('POST', `/api/orcamentos/${orcamentoId}/recusar`);
    assert.equal(reRecusar.status, 400);
});

test('listagem filtra por status', async () => {
    const pendenteId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });
    const recusadoId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });
    await amb.api('POST', `/api/orcamentos/${recusadoId}/recusar`);

    const pendentes = await amb.api('GET', '/api/orcamentos?status=Pendente');
    assert.ok(pendentes.body.some((o) => o.id === pendenteId), 'não achou o pendente no filtro Pendente');
    assert.ok(!pendentes.body.some((o) => o.id === recusadoId), 'filtro Pendente trouxe um recusado');

    const rejeitados = await amb.api('GET', '/api/orcamentos?status=Rejeitado');
    assert.ok(rejeitados.body.some((o) => o.id === recusadoId), 'não achou o recusado no filtro Rejeitado');
    assert.ok(!rejeitados.body.some((o) => o.id === pendenteId), 'filtro Rejeitado trouxe um pendente');
});

test('soft-delete some da consulta', async () => {
    const orcamentoId = await amb.criarOrcamento({
        cliente_id: 1,
        itens: [{ produto_id: produtoId, quantidade: 1, valor_unitario: 50 }],
    });

    const del = await amb.api('DELETE', `/api/orcamentos/${orcamentoId}`);
    assert.ok(del.status === 200 || del.status === 204, `delete: ${del.status}`);

    const get = await amb.api('GET', `/api/orcamentos/${orcamentoId}`);
    assert.equal(get.status, 404);
});
