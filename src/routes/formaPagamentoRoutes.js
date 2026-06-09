const express = require('express');
const router = express.Router();
const formaPagamentoController = require('../controllers/formaPagamentoController');

router.get('/', formaPagamentoController.listarFormasPagamento);
router.post('/', formaPagamentoController.criarForma);
router.put('/:id', formaPagamentoController.atualizarForma);
router.delete('/:id', formaPagamentoController.deletarForma);

module.exports = router;
