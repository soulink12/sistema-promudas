const express = require('express');
const router = express.Router();
const entregaController = require('../controllers/entregaController');

router.post('/', entregaController.criarRetirada);
router.get('/', entregaController.listarRetiradas);
router.put('/:id', entregaController.atualizarRetirada);
router.delete('/:id', entregaController.eliminarRetirada);

module.exports = router;
