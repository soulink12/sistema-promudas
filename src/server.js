const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes.js');
const clienteRoutes = require('./routes/clienteRoutes');
const produtoRoutes = require('./routes/produtoRoutes');
const pedidoRoutes = require('./routes/pedidoRoutes');
const pagamentoRoutes = require('./routes/pagamentoRoutes');
const retiradaRoutes = require('./routes/retiradaRoutes');
const formaPagamentoRoutes = require('./routes/formaPagamentoRoutes');

const { verificarToken } = require('./middlewares/authMiddleware.js');

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
app.use('/api/clientes', clienteRoutes);
app.use('/api/produtos', produtoRoutes);
app.use('/api/pedidos', pedidoRoutes);
app.use('/api/pagamentos', pagamentoRoutes);
app.use('/api/retiradas', retiradaRoutes);

const PORT = process.env.PORT || 6072;
app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});
