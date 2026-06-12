// Seed inicial do banco — roda após `npx prisma db push`.
// Insere: 1 usuário, formas de pagamento, locais de entrega e alguns clientes.
// Uso: node prisma/seed.js
require('dotenv').config(); // carrega DATABASE_USER/PASSWORD/HOST/NAME/PORT do .env
const prisma = require('../src/config/database');
const bcrypt = require('bcrypt');

async function main() {
    // ── Limpeza (ordem segura de FK) — torna o seed re-executável ───────────
    // Preserva `produtos` (não são recriados aqui).
    await prisma.itens_entrega.deleteMany();
    await prisma.itens_pedido.deleteMany();
    await prisma.entregas.deleteMany();
    await prisma.pagamentos.deleteMany();
    await prisma.pedidos.deleteMany();
    await prisma.clientes.deleteMany();
    await prisma.formas_pagamento.deleteMany();
    await prisma.locais_entrega.deleteMany();
    await prisma.contas.deleteMany();
    await prisma.usuarios.deleteMany();

    // ── Usuário (login do sistema) ──────────────────────────────────────────
    const senhaHash = await bcrypt.hash('admin123', 10);
    await prisma.usuarios.create({
        data: {
            nome: 'Administrador',
            email: 'admin@promudas.com',
            senha_hash: senhaHash,
            ativo: true,
        },
    });

    // ── Formas de pagamento ─────────────────────────────────────────────────
    await prisma.formas_pagamento.createMany({
        data: [
            // conta_posterior = a conta é definida depois (não no PDV); fica "pendente"
            { nome: 'Dinheiro', pagamento_posterior: false, conta_posterior: true },
            { nome: 'PIX', pagamento_posterior: false, conta_posterior: false },
            { nome: 'Cartão de Débito', pagamento_posterior: false, conta_posterior: false },
            { nome: 'Cartão de Crédito', pagamento_posterior: false, conta_posterior: false },
            { nome: 'Crediário', pagamento_posterior: true, conta_posterior: false },
        ],
    });

    // ── Locais de entrega ───────────────────────────────────────────────────
    await prisma.locais_entrega.createMany({
        data: [{ nome: 'Paraíso' }, { nome: 'BR' }, { nome: 'Doze' }],
    });

    // ── Contas (para onde o pagamento entra) ────────────────────────────────
    await prisma.contas.createMany({
        data: [
            { nome: 'Fernando Antônio' },
            { nome: 'Fernando de Sousa' },
            { nome: 'Lucas' },
            { nome: 'Fábio' },
        ],
    });

    // ── Clientes (id=1 = Consumidor Padrão / venda balcão) ──────────────────
    await prisma.clientes.create({ data: { id: 1, nome: 'Consumidor' } });
    await prisma.clientes.createMany({
        data: [
            { nome: 'João da Silva', cpf_cnpj: '123.456.789-00', telefone_1: '(94) 99999-0001', cidade: 'Parauapebas', estado: 'PA' },
            { nome: 'Maria Oliveira', cpf_cnpj: '987.654.321-00', telefone_1: '(94) 99999-0002', cidade: 'Parauapebas', estado: 'PA' },
            { nome: 'Sítio Boa Esperança', cpf_cnpj: '12.345.678/0001-90', telefone_1: '(94) 98888-0003', cidade: 'Canaã dos Carajás', estado: 'PA' },
        ],
    });

    console.log('✓ Seed concluído: 1 usuário (admin@promudas.com / admin123), 5 formas de pagamento, 3 locais de entrega, 4 contas, 4 clientes.');
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error('Erro no seed:', e);
        process.exit(1);
    });
