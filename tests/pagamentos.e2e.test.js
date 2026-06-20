// Teste e2e do backend — fluxo financeiro de pagamentos (HTTP → service → Prisma → banco).
// Runner nativo do Node (`node --test`) + `fetch` global — sem dependências novas.
//
// ⚠️ ESCREVE NO BANCO configurado no .env. Rodar só contra o banco de TESTE/descartável.
// O teste é autolimpante: cria apenas os próprios dados (um produto descartável e
// alguns pedidos) e apaga só eles no final. NUNCA roda migrate reset / seed.
//
// Uso: npm test   (ou: node --test tests/)
// Override de credenciais: TEST_USER_EMAIL / TEST_USER_SENHA.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const app = require('../src/server');
const prisma = require('../src/config/database');

const EMAIL = process.env.TEST_USER_EMAIL || 'lucasgsalbuquerque@gmail.com';
const SENHA = process.env.TEST_USER_SENHA || '987741';

let server;
let baseUrl;
let token;
let produtoId;
const pedidosCriados = [];

// Helper: chamada autenticada à API. Retorna { status, body } (body já parseado).
async function api(method, path, corpo) {
    const res = await fetch(`${baseUrl}${path}`, {
        method,
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
        },
        body: corpo ? JSON.stringify(corpo) : undefined,
    });
    const texto = await res.text();
    let body = null;
    try { body = texto ? JSON.parse(texto) : null; } catch { body = texto; }
    return { status: res.status, body };
}

// Cria um pedido total 100 (Consumidor id=1, produto descartável × 2 a 50) e
// registra o id para limpeza posterior. Retorna o id do pedido.
async function criarPedido() {
    const res = await api('POST', '/api/pedidos', {
        cliente_id: 1,
        valor_total: 100,
        itens: [{ produto_id: produtoId, quantidade: 2, valor_unitario: 50 }],
    });
    assert.equal(res.status, 201, `criar pedido falhou: ${JSON.stringify(res.body)}`);
    const id = res.body.data.id;
    pedidosCriados.push(id);
    return id;
}

// Lê o status_pagamento atual do pedido via API.
async function statusPagamento(pedidoId) {
    const res = await api('GET', `/api/pedidos/${pedidoId}`);
    assert.equal(res.status, 200, `buscar pedido falhou: ${JSON.stringify(res.body)}`);
    return res.body.status_pagamento;
}

before(async () => {
    // Sobe o app numa porta efêmera (não colide com o backend que talvez esteja na 6072).
    server = app.listen(0);
    await new Promise((resolve) => server.once('listening', resolve));
    baseUrl = `http://127.0.0.1:${server.address().port}`;

    // Login → token JWT.
    const res = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: EMAIL, senha: SENHA }),
    });
    const body = await res.json();
    assert.equal(res.status, 200, `login falhou (${res.status}): ${JSON.stringify(body)}`);
    token = body.token;
    assert.ok(token, 'login não retornou token');

    // Produto descartável criado direto via Prisma (id usado nos pedidos do teste).
    const produto = await prisma.produtos.create({
        data: { nome: `__e2e_produto_${Date.now()}`, preco: 50 },
    });
    produtoId = produto.id;
});

after(async () => {
    // Limpeza: apaga os pedidos criados (cascade remove itens_pedido e pagamentos),
    // depois o produto (ordem importa por causa da FK itens_pedido → produtos).
    for (const id of pedidosCriados) {
        try { await prisma.pedidos.delete({ where: { id } }); } catch { /* já removido */ }
    }
    if (produtoId) {
        try { await prisma.produtos.delete({ where: { id: produtoId } }); } catch { /* idem */ }
    }
    await prisma.$disconnect();
    await new Promise((resolve) => server.close(resolve));
});

test('pagamento parcial leva a Parcial e depois a Pago', async () => {
    const pedidoId = await criarPedido();
    assert.equal(await statusPagamento(pedidoId), 'Pendente', 'status inicial deveria ser Pendente');

    // Paga 40 de 100 → Parcial.
    let pg = await api('POST', '/api/pagamentos', {
        pedido_id: pedidoId, valor_pago: 40, forma_pagamento: 'PIX',
        data_pagamento: new Date().toISOString(),
    });
    assert.equal(pg.status, 201, `1º pagamento falhou: ${JSON.stringify(pg.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Parcial');

    // Paga os 60 restantes → Pago.
    pg = await api('POST', '/api/pagamentos', {
        pedido_id: pedidoId, valor_pago: 60, forma_pagamento: 'PIX',
        data_pagamento: new Date().toISOString(),
    });
    assert.equal(pg.status, 201, `2º pagamento falhou: ${JSON.stringify(pg.body)}`);
    assert.equal(await statusPagamento(pedidoId), 'Pago');
});

test('pagamento que excede o total é rejeitado e não altera o status', async () => {
    const pedidoId = await criarPedido();

    const pg = await api('POST', '/api/pagamentos', {
        pedido_id: pedidoId, valor_pago: 150, forma_pagamento: 'PIX',
        data_pagamento: new Date().toISOString(),
    });
    assert.equal(pg.status, 400, `esperava 400, veio: ${JSON.stringify(pg.body)}`);
    assert.match(pg.body.erro, /excede/i);

    // Nada foi gravado → segue Pendente.
    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});

test('crediário (pagamento posterior) não conta como recebido', async () => {
    const pedidoId = await criarPedido();

    const pg = await api('POST', '/api/pagamentos', {
        pedido_id: pedidoId, valor_pago: 100, forma_pagamento: 'Crediário',
        data_pagamento: new Date().toISOString(),
    });
    assert.equal(pg.status, 201, `crediário falhou: ${JSON.stringify(pg.body)}`);

    // Crediário é "a receber", não soma ao total real → status segue Pendente.
    assert.equal(await statusPagamento(pedidoId), 'Pendente');
});
