const contaService = require('../services/contaService');

const listarContas = async (req, res) => {
    try {
        const contas = await contaService.listarContas();
        return res.status(200).json(contas);
    } catch (error) {
        console.error('Erro ao listar contas:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

module.exports = { listarContas };
