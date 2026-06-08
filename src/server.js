const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes.js');
const clienteRoutes = require('./routes/clienteRoutes');
const variedadeRoutes = require('./routes/variedadeRoutes');
const encomendaRoutes = require('./routes/encomendaRoutes');
const pagamentoRoutes = require('./routes/pagamentoRoutes');
const entregaRoutes = require('./routes/entregaRoutes');
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
app.use('/api/produtos', variedadeRoutes);
app.use('/api/pedidos', encomendaRoutes);
app.use('/api/pagamentos', pagamentoRoutes);
app.use('/api/retiradas', entregaRoutes);

const PORT = process.env.PORT || 6072;
app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});
