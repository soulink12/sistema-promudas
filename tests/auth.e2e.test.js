// e2e — autenticação (login, registro, proteção de rotas via JWT).

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente, marcador, EMAIL, SENHA } = require('./helpers');

let amb;

before(async () => {
    amb = await criarAmbiente();
    await amb.login();
});

after(async () => {
    await amb.encerrar();
});

test('login com credenciais válidas retorna token e usuário', async () => {
    const res = await amb.api('POST', '/api/auth/login', {
        semToken: true,
        body: { email: EMAIL, senha: SENHA },
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
    assert.ok(res.body.token, 'sem token');
    assert.ok(res.body.usuario?.id, 'sem usuario.id');
});

test('login com senha errada retorna 401', async () => {
    const res = await amb.api('POST', '/api/auth/login', {
        semToken: true,
        body: { email: EMAIL, senha: 'senha-errada-123' },
    });
    assert.equal(res.status, 401);
    assert.match(res.body.erro, /inv[aá]lid/i);
});

test('login com email inexistente retorna 401', async () => {
    const res = await amb.api('POST', '/api/auth/login', {
        semToken: true,
        body: { email: 'naoexiste@e2e.test', senha: '123456' },
    });
    assert.equal(res.status, 401);
});

test('registrar novo usuário permite login depois; email duplicado é rejeitado', async () => {
    const email = `${marcador('user')}@e2e.test`;
    const senha = 'segredo123';

    const reg = await amb.api('POST', '/api/auth/registrar', {
        semToken: true,
        body: { nome: 'E2E User', email, senha },
    });
    assert.equal(reg.status, 201, JSON.stringify(reg.body));
    if (reg.body.usuarioId) amb.registrar.usuario(reg.body.usuarioId);

    // Consegue logar com o usuário recém-criado.
    const login = await amb.api('POST', '/api/auth/login', {
        semToken: true,
        body: { email, senha },
    });
    assert.equal(login.status, 200, JSON.stringify(login.body));

    // Registrar o mesmo email de novo → 400.
    const dup = await amb.api('POST', '/api/auth/registrar', {
        semToken: true,
        body: { nome: 'Outro', email, senha },
    });
    assert.equal(dup.status, 400);
    assert.match(dup.body.erro, /uso/i);
});

test('rota protegida sem token retorna 403', async () => {
    const res = await amb.api('GET', '/api/clientes', { semToken: true });
    assert.equal(res.status, 403);
});

test('rota protegida com token inválido retorna 401', async () => {
    const res = await amb.api('GET', '/api/clientes', { token: 'token-invalido' });
    assert.equal(res.status, 401);
});
