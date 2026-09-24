// Diagnóstico (só leitura) de linhas de crediário desatualizadas — pedidos
// onde a soma dos pagamentos de forma "posterior" (crediário) gravada no
// banco não bate com valor_total - soma dos pagamentos reais. Isso podia
// acontecer antes da correção da reconciliação de crediário: excluir/editar
// um pagamento real, ou editar os itens do pedido, não atualizava a linha
// de crediário já lançada — o PDF/relatório (que leem o valor cru do banco)
// ficavam com o valor antigo, mesmo a tela mostrando o valor certo (ela
// sempre recalculava na hora).
//
// Não escreve nada. Uso: node scripts/diagnosticoCrediario.js
require('dotenv').config();
const prisma = require('../src/config/database');
const formaPagamentoService = require('../src/services/formaPagamentoService');

// Reaproveitada por scripts/corrigirCrediario.js — mesma consulta, pra a
// correção pontual nunca divergir do diagnóstico que o usuário revisou.
async function encontrarDivergentes() {
    const formasPosteriores = await formaPagamentoService.listarPosteriores();
    const nomesPosteriores = new Set(formasPosteriores.map(f => f.nome));

    const pedidos = await prisma.pedidos.findMany({
        where: { ativo: true, pagamentos: { some: { forma_pagamento: { in: [...nomesPosteriores] } } } },
        include: { pagamentos: true },
    });

    const divergentes = [];
    for (const pedido of pedidos) {
        const totalPagoReal = pedido.pagamentos
            .filter(p => !nomesPosteriores.has(p.forma_pagamento))
            .reduce((s, p) => s + parseFloat(p.valor_pago), 0);
        const totalCreditoAtual = pedido.pagamentos
            .filter(p => nomesPosteriores.has(p.forma_pagamento))
            .reduce((s, p) => s + parseFloat(p.valor_pago), 0);
        const saldoCorreto = Math.max(0, parseFloat(pedido.valor_total) - totalPagoReal);

        if (Math.abs(saldoCorreto - totalCreditoAtual) > 0.005) {
            divergentes.push({
                pedido_id: pedido.id,
                valor_total: parseFloat(pedido.valor_total),
                totalPagoReal,
                totalCreditoAtual,
                saldoCorreto,
                diferenca: saldoCorreto - totalCreditoAtual,
            });
        }
    }

    return { divergentes, totalComCredito: pedidos.length };
}

async function main() {
    const { divergentes, totalComCredito } = await encontrarDivergentes();

    console.table(divergentes);
    console.log(`${divergentes.length} pedido(s) com crediário divergente de ${totalComCredito} com crediário.`);
    if (divergentes.length > 0) {
        console.log('\nPara aplicar a correção: node scripts/corrigirCrediario.js --confirmar');
    }
    await prisma.$disconnect();
}

module.exports = { encontrarDivergentes };

if (require.main === module) {
    main().catch(async (err) => {
        console.error(err);
        await prisma.$disconnect();
        process.exit(1);
    });
}
