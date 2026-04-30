const express = require('express');
const router = express.Router();
const entregaController = require('../controllers/entregaController');

router.post('/', entregaController.criarEntrega);
router.get('/', entregaController.listarEntregas);
router.put('/:id', entregaController.atualizarEntrega);
router.delete('/:id', entregaController.eliminarEntrega);

module.exports = router;