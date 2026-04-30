const express = require('express');
const router = express.Router();
const pagamentoController = require('../controllers/pagamentoController');

router.post('/', pagamentoController.criarPagamento);
router.get('/', pagamentoController.listarPagamentos);
router.put('/:id', pagamentoController.atualizarPagamento);
router.delete('/:id', pagamentoController.eliminarPagamento);

module.exports = router;