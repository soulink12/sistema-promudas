// Infra compartilhada dos testes e2e de backend.
// Cada arquivo de teste cria um "ambiente": sobe o app numa porta efêmera, faz
// login e expõe helpers de chamada à API + fábricas que registram os dados
// criados para limpeza automática (hard-delete via Prisma, na ordem de FK).
//
// ⚠️ Escreve no banco do .env — rodar só contra o banco de TESTE/descartável.

const app = require('../src/server');
const prisma = require('../src/config/database');

const EMAIL = process.env.TEST_USER_EMAIL || 'lucasgsalbuquerque@gmail.com';
const SENHA = process.env.TEST_USER_SENHA || '987741';

// Marcador único para nomes/e-mails dos dados descartáveis criados nos testes.
function marcador(prefixo) {
    return `__e2e_${prefixo}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

async function criarAmbiente() {
    const server = app.listen(0);
    await new Promise((resolve) => server.once('listening', resolve));
    const baseUrl = `http://127.0.0.1:${server.address().port}`;

    let token = null;

    // Ids dos dados criados, para limpeza ao final (ordem de FK aplicada em encerrar()).
    const lixo = {
        pedidos: new Set(),
        produtos: new Set(),
        clientes: new Set(),
        usuarios: new Set(),
        formas: new Set(),
    };

    // Chamada JSON. Opções: { body, token (override), semToken }.
    async function api(method, path, { body, token: tokenOverride, semToken } = {}) {
        const headers = { 'Content-Type': 'application/json' };
        const usar = tokenOverride !== undefined ? tokenOverride : (semToken ? null : token);
        if (usar) headers.Authorization = `Bearer ${usar}`;
        const res = await fetch(`${baseUrl}${path}`, {
            method,
            headers,
            body: body !== undefined ? JSON.stringify(body) : undefined,
        });
        const texto = await res.text();
        let parsed = null;
        try { parsed = texto ? JSON.parse(texto) : null; } catch { parsed = texto; }
        return { status: res.status, body: parsed };
    }

    // Chamada que devolve bytes crus (para os endpoints de PDF).
    async function apiBytes(method, path) {
        const headers = {};
        if (token) headers.Authorization = `Bearer ${token}`;
        const res = await fetch(`${baseUrl}${path}`, { method, headers });
        const bytes = Buffer.from(await res.arrayBuffer());
        return { status: res.status, bytes };
    }

    async function login() {
        const res = await api('POST', '/api/auth/login', {
            semToken: true,
            body: { email: EMAIL, senha: SENHA },
        });
        if (res.status !== 200 || !res.body?.token) {
            throw new Error(`login falhou (${res.status}): ${JSON.stringify(res.body)}`);
        }
        token = res.body.token;
        return token;
    }

    // ── Fábricas (registram para limpeza) ───────────────────────────────────
    async function criarProduto(overrides = {}) {
        const p = await prisma.produtos.create({
            data: { nome: marcador('prod'), preco: 50, ...overrides },
        });
        lixo.produtos.add(p.id);
        return p;
    }

    async function criarCliente(overrides = {}) {
        const c = await prisma.clientes.create({
            data: { nome: marcador('cli'), ...overrides },
        });
        lixo.clientes.add(c.id);
        return c;
    }

    // Cria um pedido pela API (fluxo real). valor_total default = soma dos itens.
    async function criarPedido(corpo) {
        const valor_total = corpo.valor_total ?? corpo.itens.reduce(
            (s, i) => s + Number(i.valor_unitario) * Number(i.quantidade), 0);
        const res = await api('POST', '/api/pedidos', { body: { ...corpo, valor_total } });
        if (res.status !== 201) {
            throw new Error(`criar pedido falhou (${res.status}): ${JSON.stringify(res.body)}`);
        }
        const id = res.body.data.id;
        lixo.pedidos.add(id);
        return id;
    }

    // Registro manual para dados criados pela própria API no teste (usuário, forma…).
    const registrar = {
        pedido: (id) => lixo.pedidos.add(id),
        produto: (id) => lixo.produtos.add(id),
        cliente: (id) => lixo.clientes.add(id),
        usuario: (id) => lixo.usuarios.add(id),
        forma: (id) => lixo.formas.add(id),
    };

    async function encerrar() {
        // Ordem de FK: pedido (cascade apaga itens/pagamentos/entregas) → produto →
        // cliente → usuario → forma. Cada delete é tolerante a falha.
        for (const id of lixo.pedidos) await prisma.pedidos.delete({ where: { id } }).catch(() => {});
        for (const id of lixo.produtos) await prisma.produtos.delete({ where: { id } }).catch(() => {});
        for (const id of lixo.clientes) await prisma.clientes.delete({ where: { id } }).catch(() => {});
        for (const id of lixo.usuarios) await prisma.usuarios.delete({ where: { id } }).catch(() => {});
        for (const id of lixo.formas) await prisma.formas_pagamento.delete({ where: { id } }).catch(() => {});
        await prisma.$disconnect();
        await new Promise((resolve) => server.close(resolve));
    }

    return {
        baseUrl,
        api,
        apiBytes,
        login,
        criarProduto,
        criarCliente,
        criarPedido,
        registrar,
        encerrar,
        get token() { return token; },
    };
}

module.exports = { criarAmbiente, prisma, marcador, EMAIL, SENHA };
