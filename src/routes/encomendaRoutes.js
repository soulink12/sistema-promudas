const express = require('express');
const router = express.Router();
const encomendaController = require('../controllers/encomendaController');

router.post('/', encomendaController.criarPedido);
router.get('/', encomendaController.listarPedidos);
router.put('/:id', encomendaController.atualizarPedido);
router.delete('/:id', encomendaController.eliminarPedido);

module.exports = router;
