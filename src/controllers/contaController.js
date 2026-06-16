const contaService = require('../services/contaService');

const listarContas = async (req, res, next) => {
    try {
        const contas = await contaService.listarContas();
        return res.status(200).json(contas);
    } catch (erro) {
        next(erro);
    }
};

module.exports = { listarContas };
