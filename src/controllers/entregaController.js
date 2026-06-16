const entregaService = require('../services/entregaService');

const criarEntrega = async (req, res, next) => {
    try {
        const id = await entregaService.criarEntrega(req.body);
        res.status(201).json({ mensagem: 'Entrega criada com sucesso', id });
    } catch (erro) {
        next(erro);
    }
};

const listarEntregas = async (req, res, next) => {
    try {
        const entregas = await entregaService.listarEntregas({ cliente: req.query.cliente });
        res.status(200).json(entregas);
    } catch (erro) {
        next(erro);
    }
};

const atualizarEntrega = async (req, res, next) => {
    try {
        const { id } = req.params;
        await entregaService.atualizarEntrega(id, req.body);
        res.status(200).json({ mensagem: 'Entrega atualizada com sucesso' });
    } catch (erro) {
        next(erro);
    }
};

const eliminarEntrega = async (req, res, next) => {
    try {
        const { id } = req.params;
        await entregaService.eliminarEntrega(id);
        res.status(200).json({ mensagem: 'Entrega apagada com sucesso' });
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega
};
