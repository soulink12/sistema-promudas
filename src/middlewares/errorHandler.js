// Middleware central de tratamento de erro. Erros de negócio (BusinessError) têm
// status embutido e mensagem segura; erros inesperados viram 500 genérico
// (não vaza detalhe interno ao cliente).
const errorHandler = (erro, req, res, next) => {
    console.error(erro);
    const status = erro.status || 500;
    const mensagem = erro.status ? erro.message : 'Erro interno do servidor.';
    res.status(status).json({ erro: mensagem });
};

module.exports = errorHandler;
