const entregaService = require('../services/entregaService');

const criarRetirada = async (req, res) => {
    try {
        const id = await entregaService.criarRetirada(req.body);
        res.status(201).json({ mensagem: 'Retirada criada com sucesso', id });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao criar retirada', detalhe: erro.message });
    }
};

const listarRetiradas = async (req, res) => {
    try {
        const retiradas = await entregaService.listarRetiradas();
        res.status(200).json(retiradas);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar retiradas', detalhe: erro.message });
    }
};

const atualizarRetirada = async (req, res) => {
    try {
        const { id } = req.params;
        await entregaService.atualizarRetirada(id, req.body);
        res.status(200).json({ mensagem: 'Retirada atualizada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao atualizar retirada', detalhe: erro.message });
    }
};

const eliminarRetirada = async (req, res) => {
    try {
        const { id } = req.params;
        await entregaService.eliminarRetirada(id);
        res.status(200).json({ mensagem: 'Retirada apagada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao apagar retirada', detalhe: erro.message });
    }
};

module.exports = {
    criarRetirada,
    listarRetiradas,
    atualizarRetirada,
    eliminarRetirada
};
