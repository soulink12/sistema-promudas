const entregaService = require('../services/entregaService');

const criarEntrega = async (req, res) => {
    try {
        const id = await entregaService.criarEntrega(req.body);
        res.status(201).json({ mensagem: 'Entrega criada com sucesso', id });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao criar entrega' });
    }
};

const listarEntregas = async (req, res) => {
    try {
        const entregas = await entregaService.listarEntregas({ cliente: req.query.cliente });
        res.status(200).json(entregas);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar entregas' });
    }
};

const atualizarEntrega = async (req, res) => {
    try {
        const { id } = req.params;
        await entregaService.atualizarEntrega(id, req.body);
        res.status(200).json({ mensagem: 'Entrega atualizada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao atualizar entrega' });
    }
};

const eliminarEntrega = async (req, res) => {
    try {
        const { id } = req.params;
        await entregaService.eliminarEntrega(id);
        res.status(200).json({ mensagem: 'Entrega apagada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao apagar entrega' });
    }
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega
};
