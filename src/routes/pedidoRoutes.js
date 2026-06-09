const express = require('express');
const router = express.Router();
const pedidoController = require('../controllers/pedidoController');

router.post('/', pedidoController.criarPedido);
router.get('/', pedidoController.listarPedidos);
router.get('/:id/pdf', pedidoController.gerarPDF);
router.put('/:id', pedidoController.atualizarPedido);
router.delete('/:id', pedidoController.eliminarPedido);

module.exports = router;
