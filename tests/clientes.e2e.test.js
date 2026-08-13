// e2e — CRUD de clientes (criar, buscar, listar, busca, atualizar, soft-delete).

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { criarAmbiente, marcador, gerarCpfValido } = require('./helpers');

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
    const cpf = gerarCpfValido();

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

test('rejeita cpf/cnpj duplicado ao criar cliente', async () => {
    const cpf = gerarCpfValido();
    const c1 = await amb.criarCliente({ cpf_cnpj: cpf });
    amb.registrar.cliente(c1.id);

    const resp = await amb.api('POST', '/api/clientes', {
        body: { nome: marcador('cli'), cpf_cnpj: cpf },
    });
    assert.equal(resp.status, 400, JSON.stringify(resp.body));
    assert.match(resp.body.erro, /cpf.*cnpj/i);
});

test('rejeita cpf com dígito verificador inválido', async () => {
    const valido = gerarCpfValido();
    // Mesma base, último dígito verificador propositalmente errado.
    const invalido = valido.slice(0, -1) + (valido.at(-1) === '0' ? '1' : '0');

    const resp = await amb.api('POST', '/api/clientes', {
        body: { nome: marcador('cli'), cpf_cnpj: invalido },
    });
    assert.equal(resp.status, 400, JSON.stringify(resp.body));
});

test('armazena cpf/cnpj só com dígitos mesmo recebendo valor formatado', async () => {
    const nome = marcador('cli');
    const base = gerarCpfValido();
    const formatado = `${base.slice(0, 3)}.${base.slice(3, 6)}.${base.slice(6, 9)}-${base.slice(9)}`;

    const criar = await amb.api('POST', '/api/clientes', { body: { nome, cpf_cnpj: formatado } });
    assert.equal(criar.status, 201, JSON.stringify(criar.body));
    const id = criar.body.id;
    amb.registrar.cliente(id);

    const busca = await amb.api('GET', `/api/clientes/${id}`);
    assert.equal(busca.body.cpf_cnpj, base);
});

test('rejeita cpf/cnpj duplicado ao editar cliente', async () => {
    const cpfA = gerarCpfValido();
    const a = await amb.criarCliente({ cpf_cnpj: cpfA });
    amb.registrar.cliente(a.id);
    const b = await amb.criarCliente({ cpf_cnpj: gerarCpfValido() });
    amb.registrar.cliente(b.id);

    const resp = await amb.api('PUT', `/api/clientes/${b.id}`, {
        body: { cpf_cnpj: cpfA },
    });
    assert.equal(resp.status, 400, JSON.stringify(resp.body));
    assert.match(resp.body.erro, /cpf.*cnpj/i);
});

test('rejeita cpf com dígito verificador inválido ao editar', async () => {
    const c = await amb.criarCliente({});
    amb.registrar.cliente(c.id);

    const valido = gerarCpfValido();
    const invalido = valido.slice(0, -1) + (valido.at(-1) === '0' ? '1' : '0');

    const resp = await amb.api('PUT', `/api/clientes/${c.id}`, {
        body: { cpf_cnpj: invalido },
    });
    assert.equal(resp.status, 400, JSON.stringify(resp.body));
});

test('armazena cpf/cnpj só com dígitos mesmo recebendo valor formatado ao editar', async () => {
    const base = gerarCpfValido();
    const formatado = `${base.slice(0, 3)}.${base.slice(3, 6)}.${base.slice(6, 9)}-${base.slice(9)}`;
    const c = await amb.criarCliente({});
    amb.registrar.cliente(c.id);

    const upd = await amb.api('PUT', `/api/clientes/${c.id}`, {
        body: { cpf_cnpj: formatado },
    });
    assert.equal(upd.status, 200, JSON.stringify(upd.body));

    const busca = await amb.api('GET', `/api/clientes/${c.id}`);
    assert.equal(busca.body.cpf_cnpj, base);
});

test('editar cliente mantendo o próprio cpf/cnpj não gera falso positivo de duplicidade', async () => {
    const cpf = gerarCpfValido();
    const c = await amb.criarCliente({ cpf_cnpj: cpf });
    amb.registrar.cliente(c.id);

    // Reenvia o mesmo CPF (formatado) junto com outra alteração — não pode
    // ser barrado como "duplicado" por colidir consigo mesmo.
    const formatado = `${cpf.slice(0, 3)}.${cpf.slice(3, 6)}.${cpf.slice(6, 9)}-${cpf.slice(9)}`;
    const resp = await amb.api('PUT', `/api/clientes/${c.id}`, {
        body: { nome: `${c.nome}_editado`, cpf_cnpj: formatado },
    });
    assert.equal(resp.status, 200, JSON.stringify(resp.body));

    const busca = await amb.api('GET', `/api/clientes/${c.id}`);
    assert.equal(busca.body.cpf_cnpj, cpf);
    assert.match(busca.body.nome, /_editado$/);
});
