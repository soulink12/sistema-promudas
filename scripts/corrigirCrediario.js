// Aplica a correção pontual dos pedidos com crediário divergente (achados por
// scripts/diagnosticoCrediario.js) — reusa a MESMA reconciliação que passou a
// rodar em runtime (pagamentoService.reconciliarCrediarioPedido), pra garantir
// que a correção manual seja idêntica à lógica que já roda em produção dali
// pra frente.
//
// Por padrão é dry-run (só lista o que faria). Só escreve no banco com a
// flag --confirmar.
//
// Uso:
//   node scripts/corrigirCrediario.js              (dry-run)
//   node scripts/corrigirCrediario.js --confirmar   (aplica de verdade)
require('dotenv').config();
const prisma = require('../src/config/database');
const { encontrarDivergentes } = require('./diagnosticoCrediario');
const { reconciliarCrediarioPedido } = require('../src/services/pagamentoService');

async function main() {
    const aplicar = process.argv.includes('--confirmar');
    const { divergentes } = await encontrarDivergentes();

    if (divergentes.length === 0) {
        console.log('Nenhum pedido com crediário divergente encontrado.');
        await prisma.$disconnect();
        return;
    }

    for (const d of divergentes) {
        console.log(`Pedido ${d.pedido_id}: crediário ${d.totalCreditoAtual.toFixed(2)} -> ${d.saldoCorreto.toFixed(2)}`);
        if (aplicar) {
            // usuarioId null: script de manutenção, sem usuário humano — o log
            // de atividade fica sem autor, igual a qualquer ação automática do
            // sistema (mesmo padrão de recalcularStatusPedido/seed).
            await reconciliarCrediarioPedido(d.pedido_id, null);
        }
    }

    if (!aplicar) {
        console.log(`\n${divergentes.length} pedido(s) seriam corrigidos — dry-run, nada foi escrito.`);
        console.log('Rode com --confirmar para aplicar de verdade.');
    } else {
        console.log(`\n${divergentes.length} pedido(s) corrigido(s).`);
    }

    await prisma.$disconnect();
}

if (require.main === module) {
    main().catch(async (err) => {
        console.error(err);
        await prisma.$disconnect();
        process.exit(1);
    });
}
