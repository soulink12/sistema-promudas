const temporadaService = require('../services/temporadaService');

const listarTemporadas = async (req, res, next) => {
    try {
        const temporadas = await temporadaService.listarTemporadas();
        res.status(200).json(temporadas);
    } catch (erro) {
        next(erro);
    }
};

const criarTemporada = async (req, res, next) => {
    try {
        const { ano } = req.body;
        if (ano === undefined || ano === null || ano === '') {
            return res.status(400).json({ erro: 'O campo ano é obrigatório.' });
        }
        const nova = await temporadaService.criarTemporada(ano);
        res.status(201).json(nova);
    } catch (erro) {
        next(erro);
    }
};

const ativarTemporada = async (req, res, next) => {
    try {
        const id = parseInt(req.params.id);
        const ativada = await temporadaService.definirAtiva(id);
        res.status(200).json(ativada);
    } catch (erro) {
        next(erro);
    }
};

module.exports = { listarTemporadas, criarTemporada, ativarTemporada };
