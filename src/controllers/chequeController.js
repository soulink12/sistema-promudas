const chequeService = require('../services/chequeService');

const listarChequesADepositar = async (req, res, next) => {
    try {
        const cheques = await chequeService.listarChequesADepositar();
        res.status(200).json(cheques);
    } catch (erro) {
        next(erro);
    }
};

const atualizarCheque = async (req, res, next) => {
    try {
        const { id } = req.params;
        await chequeService.atualizarCheque(id, req.body);
        res.status(200).json({ mensagem: 'Cheque atualizado com sucesso' });
    } catch (erro) {
        next(erro);
    }
};

module.exports = { listarChequesADepositar, atualizarCheque };
