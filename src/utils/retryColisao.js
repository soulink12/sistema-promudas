// Reexecuta `fn` quando ela falhar com um erro de constraint única do Prisma
// (P2002) — usado onde duas escritas concorrentes podem calcular o mesmo
// próximo número sequencial (ex.: numero_temporada) antes de qualquer uma
// gravar. Um pequeno atraso aleatório entre tentativas evita que corridas
// concorrentes colidam de novo umas com as outras a cada retry.
const retryColisao = async (fn, tentativas = 5) => {
    for (let tentativa = 1; tentativa <= tentativas; tentativa++) {
        try {
            return await fn();
        } catch (erro) {
            if (erro.code !== 'P2002' || tentativa === tentativas) throw erro;
            await new Promise((resolve) => setTimeout(resolve, Math.random() * 50));
        }
    }
};

module.exports = { retryColisao };
