const entregaService = require('../services/entregaService');

const criarEntrega = async (req, res) => {
    try {
        const id = await entregaService.criarEntrega(req.body);
        res.status(201).json({ mensagem: 'Entrega criada com sucesso', id });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao criar entrega', detalhe: erro.message });
    }
};

const listarEntregas = async (req, res) => {
    try {
        const entregas = await entregaService.listarEntregas();
        res.status(200).json(entregas);
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao listar entregas', detalhe: erro.message });
    }
};

const atualizarEntrega = async (req, res) => {
    try {
        const { id } = req.params;
        const dados = req.body;
        await entregaService.atualizarEntrega(id, dados);
        res.status(200).json({ mensagem: 'Entrega atualizada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao atualizar entrega', detalhe: erro.message });
    }
};

const eliminarEntrega = async (req, res) => {
    try {
        const { id } = req.params;
        await entregaService.eliminarEntrega(id);
        res.status(200).json({ mensagem: 'Entrega apagada com sucesso' });
    } catch (erro) {
        console.error(erro);
        res.status(500).json({ erro: 'Erro ao apagar entrega', detalhe: erro.message });
    }
};

module.exports = {
    criarEntrega,
    listarEntregas,
    atualizarEntrega,
    eliminarEntrega
};