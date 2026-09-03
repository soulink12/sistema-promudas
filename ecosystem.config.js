// Configuração do PM2 para o backend do sistema-promudas.
// Uso (na raiz do projeto):
//   pm2 start ecosystem.config.js        → sobe o backend
//   pm2 restart promudas-backend         → reinicia após deploy
//   pm2 logs promudas-backend            → acompanha os logs
//   pm2 save                             → grava o processo para subir no boot
module.exports = {
  apps: [
    {
      name: 'promudas-backend',
      script: 'src/server.js',
      cwd: __dirname,

      // Uma instância (Prisma/MariaDB e a porta 6072 não são compartilháveis em cluster).
      instances: 1,
      exec_mode: 'fork',

      // Reinício automático em caso de queda, com backoff.
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,

      // Reinicia se o processo passar de 500 MB de memória.
      max_memory_restart: '500M',

      // Não fica em watch — em produção o restart é manual/via deploy.
      watch: false,

      // As variáveis reais (DATABASE_*, JWT_SECRET, PORT, RESEND_API_KEY,
      // EMAIL_REMETENTE) vêm do .env via dotenv. Aqui só garantimos o
      // ambiente de produção.
      env: {
        NODE_ENV: 'production',
      },

      // Logs com timestamp, stdout e stderr separados.
      time: true,
      out_file: './logs/backend-out.log',
      error_file: './logs/backend-error.log',
      merge_logs: true,
    },
  ],
};
