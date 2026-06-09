const express = require('express');
const router = express.Router();
const retiradaController = require('../controllers/retiradaController');

router.post('/', retiradaController.criarRetirada);
router.get('/', retiradaController.listarRetiradas);
router.put('/:id', retiradaController.atualizarRetirada);
router.delete('/:id', retiradaController.eliminarRetirada);

module.exports = router;
