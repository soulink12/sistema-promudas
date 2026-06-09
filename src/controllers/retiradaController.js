const retiradaService = require('../services/retiradaService');

const criarRetirada = async (req, res) => {
    try {
        const id = await retiradaService.criarRetirada(req.body);
        res.status(201).json({ mensagem: 'Retirada criada com sucesso', id });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao criar retirada' });
    }
};

const listarRetiradas = async (req, res) => {
    try {
        const retiradas = await retiradaService.listarRetiradas();
        res.status(200).json(retiradas);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar retiradas' });
    }
};

const atualizarRetirada = async (req, res) => {
    try {
        const { id } = req.params;
        await retiradaService.atualizarRetirada(id, req.body);
        res.status(200).json({ mensagem: 'Retirada atualizada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao atualizar retirada' });
    }
};

const eliminarRetirada = async (req, res) => {
    try {
        const { id } = req.params;
        await retiradaService.eliminarRetirada(id);
        res.status(200).json({ mensagem: 'Retirada apagada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(erro.status || 500).json({ erro: erro.message || 'Erro ao apagar retirada' });
    }
};

module.exports = {
    criarRetirada,
    listarRetiradas,
    atualizarRetirada,
    eliminarRetirada
};
