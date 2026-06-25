const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes.js');
const clienteRoutes = require('./routes/clienteRoutes');
const produtoRoutes = require('./routes/produtoRoutes');
const pedidoRoutes = require('./routes/pedidoRoutes');
const pagamentoRoutes = require('./routes/pagamentoRoutes');
const entregaRoutes = require('./routes/entregaRoutes');
const locaisEntregaRoutes = require('./routes/locaisEntregaRoutes');
const contaRoutes = require('./routes/contaRoutes');
const chequeRoutes = require('./routes/chequeRoutes');
const formaPagamentoRoutes = require('./routes/formaPagamentoRoutes');
const temporadaRoutes = require('./routes/temporadaRoutes');
const relatorioRoutes = require('./routes/relatorioRoutes');

const { verificarToken } = require('./middlewares/authMiddleware.js');
const errorHandler = require('./middlewares/errorHandler');

const prismaTest = require('./config/database');
console.log("Prisma carregado com sucesso:", !!prismaTest);

const app = express();

app.use(cors());
app.use(express.json());

// Rota pública — login e registro
app.use('/api/auth', authRoutes);

// Todas as rotas abaixo exigem token JWT válido
app.use(verificarToken);

app.use('/api/formas-pagamento', formaPagamentoRoutes);
app.use('/api/relatorios', relatorioRoutes);
app.use('/api/clientes', clienteRoutes);
app.use('/api/produtos', produtoRoutes);
app.use('/api/pedidos', pedidoRoutes);
app.use('/api/pagamentos', pagamentoRoutes);
app.use('/api/entregas', entregaRoutes);
app.use('/api/locais-entrega', locaisEntregaRoutes);
app.use('/api/contas', contaRoutes);
app.use('/api/cheques', chequeRoutes);
app.use('/api/temporadas', temporadaRoutes);

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
}

module.exports = app;
