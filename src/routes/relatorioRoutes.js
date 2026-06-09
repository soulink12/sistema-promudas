const express = require('express');
const router = express.Router();
const relatorioController = require('../controllers/relatorioController');

router.get('/pagamentos', relatorioController.relatorioPagamentos);

module.exports = router;
