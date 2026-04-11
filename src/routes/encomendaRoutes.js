const express = require('express');
const router = express.Router();
const encomendaController = require('../controllers/encomendaController');

router.post('/', encomendaController.criarEncomenda);
router.get('/', encomendaController.listarEncomendas);

module.exports = router;