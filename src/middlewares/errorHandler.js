const BusinessError = require('../utils/BusinessError');
const logService = require('../services/logService');

// Erros conhecidos do Prisma que representam um problema do cliente, não do
// servidor. Sem esse mapeamento, apagar um id inexistente ou mandar um id não
// numérico virava 500 genérico.
const ERROS_PRISMA = {
    P2025: { status: 404, mensagem: 'Registro não encontrado.' },
    P2002: { status: 409, mensagem: 'Já existe um registro com esse valor único.' },
    P2003: { status: 400, mensagem: 'Referência inválida: o registro relacionado não existe.' },
    P2000: { status: 400, mensagem: 'Valor maior que o tamanho permitido para o campo.' },
    P2011: { status: 400, mensagem: 'Campo obrigatório não informado.' },
};

// Middleware central de tratamento de erro. A mensagem só é repassada ao
// cliente quando vem de um BusinessError (texto escrito por nós) ou do
// mapeamento acima — qualquer outra coisa vira 500 genérico, para não vazar
// detalhe interno (stack, texto de parser, mensagem de driver).
const errorHandler = async (erro, req, res, next) => {
    console.error(erro);

    if (erro instanceof BusinessError) {
        return res.status(erro.status || 400).json({ erro: erro.message });
    }

    const mapeado = ERROS_PRISMA[erro?.code];
    if (mapeado) {
        return res.status(mapeado.status).json({ erro: mapeado.mensagem });
    }

    // Body malformado (express.json) — o cliente errou, mas a mensagem do
    // parser é ruído interno.
    if (erro?.type === 'entity.parse.failed' || (erro instanceof SyntaxError && erro?.status === 400)) {
        return res.status(400).json({ erro: 'Corpo da requisição inválido.' });
    }

    // Demais erros do próprio Express (payload grande demais, etc.) já trazem
    // um status 4xx correto — preserva o código, mas com texto nosso.
    if (Number.isInteger(erro?.status) && erro.status >= 400 && erro.status < 500) {
        return res.status(erro.status).json({ erro: 'Requisição inválida.' });
    }

    // Só chega aqui erro real e inesperado do programa (não BusinessError, não
    // um código Prisma conhecido, não um 4xx do Express).
    await logService.registrarErro({
        usuarioId: req.usuarioId ?? null,
        mensagem: erro?.message ?? String(erro),
        stack: erro?.stack ?? null,
        rota: req.originalUrl,
        metodoHttp: req.method,
        statusCode: 500,
        origem: 'http',
    });

    res.status(500).json({ erro: 'Erro interno do servidor.' });
};

module.exports = errorHandler;
