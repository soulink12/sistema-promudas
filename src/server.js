const express = require('express');
const cors = require('cors');
require('dotenv').config(); // Puxa as variáveis do arquivo .env

const clienteRoutes = require('./routes/clienteRoutes');
const variedadeRoutes = require('./routes/variedadeRoutes');
const variedadeController = require('./controllers/variedadeController');
const encomendaRoutes = require('./routes/encomendaRoutes');
const pagamentoRoutes = require('./routes/pagamentoRoutes');
const entregaRoutes = require('./routes/entregaRoutes');
const authRoutes = require('./routes/authRoutes.js');
const formaPagamentoRoutes = require('./routes/formaPagamentoRoutes');

const { verificarToken } = require('./middlewares/authMiddleware.js');

const prismaTest = require('./config/database');
console.log("Prisma carregado com sucesso:", !!prismaTest);

const app = express();

// Middlewares: ensinam o Express a entender JSON e permitir acessos externos
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
// Rotas públicas — não contêm dados sensíveis e são necessárias no PDV sem login
app.use('/api/formas-pagamento', formaPagamentoRoutes);
app.get('/api/produtos', variedadeController.listarProdutos);

// Toda vez que alguém acessar /api/clientes, o Express joga para o arquivo de rotas
app.use('/api/clientes', verificarToken, clienteRoutes);
app.use('/api/produtos', verificarToken, variedadeRoutes);
app.use('/api/pedidos', verificarToken, encomendaRoutes);
app.use('/api/pagamentos', verificarToken, pagamentoRoutes);
app.use('/api/retiradas', verificarToken, entregaRoutes);

// Inicia o servidor na porta 6072
const PORT = process.env.PORT || 6072;
app.listen(PORT, () => {
    console.log(`🚀 Servidor rodando na porta ${PORT}`);
});