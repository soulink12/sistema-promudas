const logService = require('../services/logService');
const { contentDisposition } = require('../utils/contentDisposition');

const filtrosDaQuery = (query) => {
    const { entidade, entidadeId, usuarioId, acao, de, ate, page, pageSize } = query;
    const filtros = {};
    if (entidade) filtros.entidade = entidade;
    if (entidadeId) filtros.entidadeId = entidadeId;
    if (usuarioId) filtros.usuarioId = usuarioId;
    if (acao) filtros.acao = acao;
    if (de) filtros.de = de;
    if (ate) filtros.ate = ate;
    if (page) filtros.page = parseInt(page, 10);
    if (pageSize) filtros.pageSize = parseInt(pageSize, 10);
    return filtros;
};

const listarAtividades = async (req, res, next) => {
    try {
        const resultado = await logService.listarAtividades(filtrosDaQuery(req.query));
        return res.status(200).json(resultado);
    } catch (erro) {
        next(erro);
    }
};

const buscarAtividade = async (req, res, next) => {
    try {
        const atividade = await logService.buscarAtividade(req.params.id);
        if (!atividade) return res.status(404).json({ erro: 'Registro de histórico não encontrado.' });
        res.json(atividade);
    } catch (erro) {
        next(erro);
    }
};

const listarErros = async (req, res, next) => {
    try {
        const { de, ate, page, pageSize } = req.query;
        const filtros = {};
        if (de) filtros.de = de;
        if (ate) filtros.ate = ate;
        if (page) filtros.page = parseInt(page, 10);
        if (pageSize) filtros.pageSize = parseInt(pageSize, 10);
        const resultado = await logService.listarErros(filtros);
        return res.status(200).json(resultado);
    } catch (erro) {
        next(erro);
    }
};

const buscarErro = async (req, res, next) => {
    try {
        const erroRegistrado = await logService.buscarErro(req.params.id);
        if (!erroRegistrado) return res.status(404).json({ erro: 'Registro de erro não encontrado.' });
        res.json(erroRegistrado);
    } catch (erro) {
        next(erro);
    }
};

const exportarAtividades = async (req, res, next) => {
    try {
        const csv = await logService.gerarExportacaoCSV(filtrosDaQuery(req.query));
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', contentDisposition('historico.csv'));
        res.send(csv);
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    listarAtividades,
    buscarAtividade,
    listarErros,
    buscarErro,
    exportarAtividades,
};
