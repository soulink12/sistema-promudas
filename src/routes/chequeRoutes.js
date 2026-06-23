const express = require('express');
const router = express.Router();
const chequeController = require('../controllers/chequeController');

// Rota específica antes da paramétrica para não ser capturada por /:id
router.get('/a-depositar', chequeController.listarChequesADepositar);
router.put('/:id', chequeController.atualizarCheque);

module.exports = router;
