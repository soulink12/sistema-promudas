const { PrismaClient } = require('@prisma/client');
const { PrismaMariaDb } = require("@prisma/adapter-mariadb");

const adapter = new PrismaMariaDb({
  host: process.env.DATABASE_HOST,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
  port: process.env.DATABASE_PORT,
  connectionLimit: 5,
  // Necessário para MySQL 8+ com auth caching_sha2_password sem SSL: sem isso,
  // o driver não consegue buscar a chave pública RSA do servidor para
  // criptografar a senha, e a conexão falha silenciosamente até estourar o pool.
  allowPublicKeyRetrieval: true,
});

const prisma = new PrismaClient({ adapter });

module.exports = prisma;