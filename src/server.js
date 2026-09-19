const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes.js');
const clienteRoutes = require('./routes/clienteRoutes');
const produtoRoutes = require('./routes/produtoRoutes');
const pedidoRoutes = require('./routes/pedidoRoutes');
const orcamentoRoutes = require('./routes/orcamentoRoutes');
const pagamentoRoutes = require('./routes/pagamentoRoutes');
const entregaRoutes = require('./routes/entregaRoutes');
const locaisEntregaRoutes = require('./routes/locaisEntregaRoutes');
const contaRoutes = require('./routes/contaRoutes');
const chequeRoutes = require('./routes/chequeRoutes');
const formaPagamentoRoutes = require('./routes/formaPagamentoRoutes');
const temporadaRoutes = require('./routes/temporadaRoutes');
const relatorioRoutes = require('./routes/relatorioRoutes');
const logRoutes = require('./routes/logRoutes');

const { verificarToken } = require('./middlewares/authMiddleware.js');
const errorHandler = require('./middlewares/errorHandler');
const logService = require('./services/logService');

const prismaTest = require('./config/database');
console.log("Prisma carregado com sucesso:", !!prismaTest);

// Sem isso o servidor sobe com configuração faltando e só quebra na primeira
// requisição — sem JWT_SECRET, por exemplo, todo login falha com erro cru.
const VARIAVEIS_OBRIGATORIAS = [
    'JWT_SECRET',
    'DATABASE_HOST',
    'DATABASE_USER',
    'DATABASE_NAME',
];

const faltando = VARIAVEIS_OBRIGATORIAS.filter((nome) => !process.env[nome]);
if (faltando.length > 0) {
    console.error(`Variáveis de ambiente obrigatórias ausentes: ${faltando.join(', ')}.`);
    console.error('Confira o .env (local) ou o .env.docker (produção) antes de subir o servidor.');
    process.exit(1);
}

const app = express();

// O cliente é um app desktop na rede local, não um site: liberar qualquer
// origem só amplia a superfície de ataque a partir do navegador. CORS_ORIGENS
// aceita uma lista separada por vírgula; sem ela, nenhuma origem de navegador
// é liberada (o app desktop não é afetado, pois não manda Origin).
const origensPermitidas = (process.env.CORS_ORIGENS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

app.use(cors({
    origin: (origin, callback) => {
        if (!origin || origensPermitidas.includes(origin)) return callback(null, true);
        callback(null, false);
    },
}));
app.use(express.json());

// Rota pública — login e registro
app.use('/api/auth', authRoutes);

// Atualizações do app desktop — arquivos servidos publicamente (a checagem de
// versão acontece antes do login, então não pode exigir JWT). A pasta `updates/`
// fica na raiz do projeto e recebe o manifesto (app-archive.json), os descritores
// de release e os zips gerados por `dart run desktop_updater:release publish`.
// `fallthrough: false` faz arquivo inexistente retornar 404 em vez de "cair"
// no `verificarToken` abaixo (que responderia 403, mascarando o arquivo que falta).
app.use('/updates', express.static(path.join(__dirname, '..', 'updates'), { fallthrough: false }));

// Todas as rotas abaixo exigem token JWT válido
app.use(verificarToken);

app.use('/api/formas-pagamento', formaPagamentoRoutes);
app.use('/api/relatorios', relatorioRoutes);
app.use('/api/clientes', clienteRoutes);
app.use('/api/produtos', produtoRoutes);
app.use('/api/pedidos', pedidoRoutes);
app.use('/api/orcamentos', orcamentoRoutes);
app.use('/api/pagamentos', pagamentoRoutes);
app.use('/api/entregas', entregaRoutes);
app.use('/api/locais-entrega', locaisEntregaRoutes);
app.use('/api/contas', contaRoutes);
app.use('/api/cheques', chequeRoutes);
app.use('/api/temporadas', temporadaRoutes);
app.use('/api/logs', logRoutes);

// Tratamento central de erro — sempre por último, depois de todas as rotas.
app.use(errorHandler);

// Só sobe o servidor quando este arquivo é executado diretamente
// (node src/server.js / nodemon). Quando importado (ex.: testes e2e), apenas
// exporta o `app` para que o teste suba numa porta efêmera própria.
if (require.main === module) {
    const PORT = process.env.PORT || 6072;
    app.listen(PORT, () => {
        console.log(`Servidor rodando na porta ${PORT}`);
    });

    // Uma promise rejeitada fora de um .catch derruba o processo inteiro sem
    // deixar rastro. Registrado só quando o servidor roda de verdade, para não
    // interferir no runner de testes, que tem o tratamento dele.
    process.on('unhandledRejection', (motivo) => {
        console.error('Promise rejeitada sem tratamento:', motivo);
        logService.registrarErro({
            mensagem: motivo?.message ?? String(motivo),
            stack: motivo?.stack ?? null,
            origem: 'unhandledRejection',
        }).catch(() => {});
    });

    process.on('uncaughtException', (erro) => {
        console.error('Exceção não capturada:', erro);
        // Tenta registrar o erro, mas nunca espera mais que 2s por isso — o
        // motivo mais comum de uncaughtException é falha de conexão com o
        // banco, e a própria escrita do log pode nunca responder.
        const tentativaDeLog = logService.registrarErro({
            mensagem: erro?.message ?? String(erro),
            stack: erro?.stack ?? null,
            origem: 'uncaughtException',
        }).catch(() => {});
        const limite = new Promise((resolve) => setTimeout(resolve, 2000));
        // Estado do processo passa a ser incerto: encerra e deixa o supervisor
        // (PM2/Docker) subir de novo, em vez de seguir rodando quebrado.
        Promise.race([tentativaDeLog, limite]).finally(() => process.exit(1));
    });
}

module.exports = app;
