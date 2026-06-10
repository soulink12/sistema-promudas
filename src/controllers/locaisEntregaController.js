const locaisEntregaService = require('../services/locaisEntregaService');

const listarLocais = async (req, res) => {
    try {
        const locais = await locaisEntregaService.listarLocais();
        return res.status(200).json(locais);
    } catch (error) {
        console.error('Erro ao listar locais de entrega:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

module.exports = { listarLocais };
