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

test('pagar parte do crediário abate o "a receber" numa transação só', async () => {
    const pedidoId = await novoPedido(); // total 100

    // Pedido nasce inteiro no crediário (nada pago ainda).
    assert.equal((await pagar(pedidoId, 100, 'Crediário')).status, 201);
    assert.equal(await statusPagamento(pedidoId), 'Pendente');

    // Cliente paga 40 em dinheiro: o crediário tem que cair para 60.
    const res = await amb.api('POST', `/api/pedidos/${pedidoId}/pagamentos`, {
        body: {
            pagamentos: [
                { valor_pago: 40, forma_pagamento: 'PIX', data_pagamento: new Date().toISOString() },
            ],
        },
    });
    assert.equal(res.status, 201, JSON.stringify(res.body));

    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    const reais = ped.body.pagamentos.filter((p) => p.pagamento_posterior !== true);
    const crediarios = ped.body.pagamentos.filter((p) => p.pagamento_posterior === true);

    const totalReal = reais.reduce((s, p) => s + Number(p.valor_pago), 0);
    const totalCredito = crediarios.reduce((s, p) => s + Number(p.valor_pago), 0);

    assert.ok(Math.abs(totalReal - 40) < 0.01, `pago real deveria ser 40, veio ${totalReal}`);
    assert.ok(Math.abs(totalCredito - 60) < 0.01, `crediário deveria cair para 60, veio ${totalCredito}`);
    assert.ok(Math.abs(totalReal + totalCredito - 100) < 0.01, 'total coberto deixou de fechar em 100');
    assert.equal(ped.body.status_pagamento, 'Parcial');
});

test('quitar o crediário inteiro remove o "a receber" e fecha o pedido', async () => {
    const pedidoId = await novoPedido(); // total 100
    assert.equal((await pagar(pedidoId, 100, 'Crediário')).status, 201);

    const res = await amb.api('POST', `/api/pedidos/${pedidoId}/pagamentos`, {
        body: {
            pagamentos: [
                { valor_pago: 100, forma_pagamento: 'PIX', data_pagamento: new Date().toISOString() },
            ],
        },
    });
    assert.equal(res.status, 201, JSON.stringify(res.body));

    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    const crediarios = ped.body.pagamentos.filter((p) => p.pagamento_posterior === true);
    assert.equal(crediarios.length, 0, 'crediário deveria ter sumido após a quitação');
    assert.equal(ped.body.status_pagamento, 'Pago');
});

test('lote de pagamentos inválido não deixa o pedido em estado parcial', async () => {
    const pedidoId = await novoPedido(); // total 100
    assert.equal((await pagar(pedidoId, 100, 'Crediário')).status, 201);

    // O segundo pagamento estoura o total: a transação inteira precisa voltar
    // atrás — nem o primeiro pagamento entra, nem o crediário é apagado.
    const res = await amb.api('POST', `/api/pedidos/${pedidoId}/pagamentos`, {
        body: {
            pagamentos: [
                { valor_pago: 40, forma_pagamento: 'PIX', data_pagamento: new Date().toISOString() },
                { valor_pago: 500, forma_pagamento: 'PIX', data_pagamento: new Date().toISOString() },
            ],
        },
    });
    assert.equal(res.status, 400, `esperava 400: ${JSON.stringify(res.body)}`);

    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    const reais = ped.body.pagamentos.filter((p) => p.pagamento_posterior !== true);
    const crediarios = ped.body.pagamentos.filter((p) => p.pagamento_posterior === true);
    const totalCredito = crediarios.reduce((s, p) => s + Number(p.valor_pago), 0);

    assert.equal(reais.length, 0, 'pagamento parcial da transação falha ficou gravado');
    assert.ok(Math.abs(totalCredito - 100) < 0.01, `crediário foi perdido: ${totalCredito}`);
    assert.equal(ped.body.status_pagamento, 'Pendente');
});

test('criar pagamento sem corpo retorna 400 (não 500)', async () => {
    const res = await amb.api('POST', '/api/pagamentos', { body: {} });
    assert.equal(res.status, 400, JSON.stringify(res.body));
});

test('valor de pagamento negativo ou não numérico é rejeitado', async () => {
    const pedidoId = await novoPedido();

    const negativo = await pagar(pedidoId, -50);
    assert.equal(negativo.status, 400, JSON.stringify(negativo.body));
    assert.match(negativo.body.erro, /maior que zero/i);

    const texto = await pagar(pedidoId, 'abc');
    assert.equal(texto.status, 400, JSON.stringify(texto.body));

    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});

test('editar pagamento não permite trocá-lo de pedido', async () => {
    const pedidoA = await novoPedido();
    const pedidoB = await novoPedido();

    const criado = await pagar(pedidoA, 100);
    assert.equal(criado.status, 201);
    assert.equal(await statusPagamento(pedidoA), 'Pago');

    // Tenta mover o pagamento para o pedido B: o campo tem que ser ignorado,
    // senão o pedido A ficaria "Pago" sem ter o dinheiro.
    const upd = await amb.api('PUT', `/api/pagamentos/${criado.body.id}`, {
        body: { pedido_id: pedidoB, valor_pago: 100 },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));

    assert.equal(await statusPagamento(pedidoA), 'Pago');
    assert.equal(await statusPagamento(pedidoB), 'Pendente');
});

test('excluir pagamento inexistente retorna 404 (não 500)', async () => {
    const res = await amb.api('DELETE', '/api/pagamentos/2000000000');
    assert.equal(res.status, 404, JSON.stringify(res.body));
});

test('lote vazio é rejeitado com 400', async () => {
    const pedidoId = await novoPedido();
    const res = await amb.api('POST', `/api/pedidos/${pedidoId}/pagamentos`, {
        body: { pagamentos: [] },
    });
    assert.equal(res.status, 400, JSON.stringify(res.body));
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

test('escambo (troca): abate o pedido, grava os kg e não fica pendente de conta', async () => {
    // Cria a forma de escambo pela API (taxa R$/kg); registra para limpeza.
    const formaNome = `__e2e_escambo_${Date.now()}`;
    const criar = await amb.api('POST', '/api/formas-pagamento', {
        body: { nome: formaNome, escambo: true, valor_kg_escambo: 25.50 },
    });
    assert.equal(criar.status, 201, `criar forma escambo: ${JSON.stringify(criar.body)}`);
    amb.registrar.forma(criar.body.id);

    const pedidoId = await novoPedido(); // total 100
    // Paga em escambo: 100 = 4 kg × 25,50? (o valor é independente — o teste
    // só verifica que o valor abate o pedido e que os kg são gravados).
    const pg = await pagar(pedidoId, 100, formaNome, { escambo_quantidade: 4 });
    assert.equal(pg.status, 201, `pagamento escambo: ${JSON.stringify(pg.body)}`);
    const pagamentoId = pg.body.id;

    // Escambo conta como recebido → pedido fica Pago.
    assert.equal(await statusPagamento(pedidoId), 'Pago');

    // Os kg fazem round-trip no detalhe do pedido.
    const ped = await amb.api('GET', `/api/pedidos/${pedidoId}`);
    const pago = ped.body.pagamentos.find((p) => p.id === pagamentoId);
    assert.ok(pago, 'pagamento de escambo não encontrado no pedido');
    assert.equal(Number(pago.escambo_quantidade), 4);

    // Escambo não é dinheiro → não aparece em "pagamentos sem conta".
    const semConta = await amb.api('GET', '/api/pagamentos/pendentes-conta');
    assert.ok(
        !semConta.body.some((p) => p.id === pagamentoId),
        'escambo não deveria aparecer como pendente de conta',
    );
});
