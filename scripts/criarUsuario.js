// Cria/atualiza usuários do sistema (tabela `usuarios`) com senha hasheada em
// bcrypt — o MESMO formato usado no login (authService.js, genSalt(10)).
//
// Idempotente: faz upsert pelo email (único). Pode rodar várias vezes; só
// cria quem não existe e atualiza nome/senha de quem já existe. NÃO apaga nada.
//
// Uso (argumentos em grupos de 3: nome, email, senha):
//   node scripts/criarUsuario.js "Nome Sobrenome" email@dominio.com senha [...]
//
// As senhas ficam só na linha de comando (não no arquivo) — limpe o histórico
// do shell depois, se quiser (ex.: `history -c`).

require('dotenv').config();
const prisma = require('../src/config/database');
const bcrypt = require('bcrypt');

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.length % 3 !== 0) {
    console.error(
      'Uso: node scripts/criarUsuario.js "<nome>" <email> <senha> [ "<nome>" <email> <senha> ... ]'
    );
    process.exit(1);
  }

  for (let i = 0; i < args.length; i += 3) {
    const nome = args[i];
    const email = args[i + 1];
    const senha = args[i + 2];

    const senha_hash = await bcrypt.hash(senha, await bcrypt.genSalt(10));

    const usuario = await prisma.usuarios.upsert({
      where: { email },
      update: { nome, senha_hash, ativo: true },
      create: { nome, email, senha_hash, ativo: true },
    });

    console.log(`✔ ${usuario.email} (${usuario.nome}) salvo — id ${usuario.id}`);
  }
}

main()
  .catch((erro) => {
    console.error('Erro ao salvar usuário:', erro.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
