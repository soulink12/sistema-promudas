const interessadoService = require('../services/interessadoService');

const criarInteressado = async (req, res, next) => {
    try {
        const dados = req.body;

        if (!dados.cliente_id || !dados.itens || !Array.isArray(dados.itens) || dados.itens.length === 0) {
            return res.status(400).json({
                erro: 'O ID do cliente e a lista de mudas de interesse (com produto e quantidade) são obrigatórios.'
            });
        }

        const novoInteressado = await interessadoService.criarInteressado(dados, req.usuarioId);
        return res.status(201).json({
            mensagem: 'Interessado registrado com sucesso!',
            data: novoInteressado
        });
    } catch (erro) {
        next(erro);
    }
};

const buscarInteressado = async (req, res, next) => {
    try {
        const interessado = await interessadoService.buscarInteressado(req.params.id);
        if (!interessado) return res.status(404).json({ erro: 'Interessado não encontrado.' });
        res.json(interessado);
    } catch (erro) {
        next(erro);
    }
};

const listarInteressados = async (req, res, next) => {
    try {
        const { cliente } = req.query;
        const filtros = {};
        if (cliente) filtros.cliente = cliente;
        const interessados = await interessadoService.listarInteressados(filtros);
        return res.status(200).json(interessados);
    } catch (erro) {
        next(erro);
    }
};

const atualizarInteressado = async (req, res, next) => {
    try {
        const interessado = await interessadoService.atualizarInteressado(req.params.id, req.body, req.usuarioId);
        res.json(interessado);
    } catch (erro) {
        next(erro);
    }
};

const eliminarInteressado = async (req, res, next) => {
    try {
        await interessadoService.eliminarInteressado(req.params.id, req.usuarioId);
        res.status(204).send();
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarInteressado,
    listarInteressados,
    buscarInteressado,
    atualizarInteressado,
    eliminarInteressado,
};
