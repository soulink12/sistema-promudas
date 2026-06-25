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
    await prisma.temporadas.deleteMany();
    await prisma.usuarios.deleteMany();

    // ── Usuários (login do sistema) ─────────────────────────────────────────
    const usuarios = [
        { nome: 'Lucas Albuquerque', email: 'lucasgsalbuquerque@gmail.com', senha: '987741' },
        { nome: 'Elionai', email: 'elionai@promudas.com', senha: '1980' },
    ];
    for (const u of usuarios) {
        await prisma.usuarios.create({
            data: {
                nome: u.nome,
                email: u.email,
                senha_hash: await bcrypt.hash(u.senha, 10),
                ativo: true,
            },
        });
    }

    // ── Formas de pagamento ─────────────────────────────────────────────────
    await prisma.formas_pagamento.createMany({
        data: [
            // conta_posterior = a conta é definida depois (não no PDV); fica "pendente"
            // deposito_posterior = gera cheques a depositar; a data do pagamento é a do depósito
            // parcelado_em_ate > 1 = libera a escolha de parcelas no PDV (ex.: crédito até 6x)
            // escambo = troca por produção (pimenta); valor calculado por kg via valor_kg_escambo
            { nome: 'Dinheiro', pagamento_posterior: false, conta_posterior: true, deposito_posterior: false, parcelado_em_ate: 1 },
            { nome: 'PIX', pagamento_posterior: false, conta_posterior: false, deposito_posterior: false, parcelado_em_ate: 1 },
            { nome: 'Cartão de Débito', pagamento_posterior: false, conta_posterior: false, deposito_posterior: false, parcelado_em_ate: 1 },
            { nome: 'Cartão de Crédito', pagamento_posterior: false, conta_posterior: false, deposito_posterior: false, parcelado_em_ate: 6 },
            { nome: 'Crediário', pagamento_posterior: true, conta_posterior: false, deposito_posterior: false, parcelado_em_ate: 1 },
            { nome: 'Cheque', pagamento_posterior: false, conta_posterior: true, deposito_posterior: true, parcelado_em_ate: 1 },
            { nome: 'Escambo', pagamento_posterior: false, conta_posterior: false, deposito_posterior: false, parcelado_em_ate: 1, escambo: true, valor_kg_escambo: 25.50 },
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

    // ── Temporadas (numeração dos pedidos por safra: 26-1, 26-2…) ───────────
    await prisma.temporadas.create({ data: { ano: 2026, ativo: true } });

    // ── Clientes (id=1 = Consumidor Padrão / venda balcão) ──────────────────
    await prisma.clientes.create({ data: { id: 1, nome: 'Consumidor' } });

    console.log('✓ Seed concluído');
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error('Erro no seed:', e);
        process.exit(1);
    });
