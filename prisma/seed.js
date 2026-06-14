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
    const senhaHash = await bcrypt.hash('987741', 10);
    await prisma.usuarios.create({
        data: {
            nome: 'Lucas Albuquerque',
            email: 'lucasgsalbuquerque@gmail.com',
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

    console.log('✓ Seed concluído');
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error('Erro no seed:', e);
        process.exit(1);
    });
