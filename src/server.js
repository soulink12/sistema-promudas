const express = require('express');
const cors = require('cors');
require('dotenv').config(); // Puxa as variáveis do arquivo .env

const clienteRoutes = require('./routes/clienteRoutes');

const prismaTest = require('./config/database');
console.log("Prisma carregado com sucesso:", !!prismaTest);

const app = express();

// Middlewares: ensinam o Express a entender JSON e permitir acessos externos
app.use(cors());
app.use(express.json());

// Toda vez que alguém acessar /api/clientes, o Express joga para o arquivo de rotas
app.use('/api/clientes', clienteRoutes); 

// Inicia o servidor na porta 6072
const PORT = process.env.PORT || 6072;
app.listen(PORT, () => {
    console.log(`🚀 Servidor rodando na porta ${PORT}`);
});