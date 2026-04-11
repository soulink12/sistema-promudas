const { PrismaClient } = require('@prisma/client');
const { PrismaMariaDb } = require("@prisma/adapter-mariadb");

const adapter = new PrismaMariaDb({
  host: process.env.DATABASE_HOST,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
  port: process.env.DATABASE_PORT,
  connectionLimit: 5,
});

const prisma = new PrismaClient({ adapter });

module.exports = prisma;