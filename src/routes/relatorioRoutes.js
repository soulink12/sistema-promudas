const express = require('express');
const router = express.Router();
const relatorioController = require('../controllers/relatorioController');

router.get('/pagamentos', relatorioController.relatorioPagamentos);
router.get('/pagamentos/pdf', relatorioController.relatorioPDF);

module.exports = router;
