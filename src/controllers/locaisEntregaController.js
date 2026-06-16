const locaisEntregaService = require('../services/locaisEntregaService');

const listarLocais = async (req, res, next) => {
    try {
        const locais = await locaisEntregaService.listarLocais();
        return res.status(200).json(locais);
    } catch (erro) {
        next(erro);
    }
};

module.exports = { listarLocais };
