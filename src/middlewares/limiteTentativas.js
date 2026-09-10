const BusinessError = require('../utils/BusinessError');

// Limitador de tentativas em memória, para proteger o login de força bruta e do
// custo de CPU do bcrypt. Em memória basta aqui: é um único processo numa rede
// local — se um dia rodar em mais de uma instância, isso precisa virar Redis.
const criarLimiteTentativas = ({ janelaMs, maxTentativas, mensagem }) => {
    const tentativas = new Map();

    // Remove entradas vencidas de vez em quando para o Map não crescer sem fim.
    const limpar = (agora) => {
        for (const [chave, registro] of tentativas) {
            if (agora > registro.expiraEm) tentativas.delete(chave);
        }
    };

    return (req, res, next) => {
        const agora = Date.now();
        if (tentativas.size > 500) limpar(agora);

        // Chave por IP + e-mail: não deixa um IP travar a conta de outra pessoa,
        // nem alguém varrer senhas de vários e-mails a partir do mesmo IP.
        const identificador = String(req.body?.email ?? '').toLowerCase();
        const chave = `${req.ip}|${identificador}`;

        // Só tentativa malsucedida conta: um acerto zera o contador. Assim
        // quem erra a senha e acerta na sequência não fica preso, e o limite
        // continua valendo para quem só erra (que é o padrão de força bruta).
        res.on('finish', () => {
            if (res.statusCode < 400) tentativas.delete(chave);
        });

        const registro = tentativas.get(chave);
        if (!registro || agora > registro.expiraEm) {
            tentativas.set(chave, { contagem: 1, expiraEm: agora + janelaMs });
            return next();
        }

        registro.contagem += 1;
        if (registro.contagem > maxTentativas) {
            const faltamSegundos = Math.ceil((registro.expiraEm - agora) / 1000);
            return next(new BusinessError(`${mensagem} Tente de novo em ${faltamSegundos}s.`, 429));
        }

        next();
    };
};

module.exports = { criarLimiteTentativas };
