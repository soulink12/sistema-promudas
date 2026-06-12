const express = require('express');
const router = express.Router();
const pagamentoController = require('../controllers/pagamentoController');

router.post('/', pagamentoController.criarPagamento);
router.get('/', pagamentoController.listarPagamentos);
router.get('/pendentes-conta', pagamentoController.listarPagamentosPendentesDeConta);
router.put('/:id', pagamentoController.atualizarPagamento);
router.delete('/:id', pagamentoController.eliminarPagamento);

module.exports = router;