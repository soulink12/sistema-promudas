const express = require('express');
const router = express.Router();
const formaPagamentoController = require('../controllers/formaPagamentoController');

router.get('/', formaPagamentoController.listarFormasPagamento);

module.exports = router;
