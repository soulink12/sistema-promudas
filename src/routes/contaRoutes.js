const express = require('express');
const router = express.Router();
const contaController = require('../controllers/contaController');

router.get('/', contaController.listarContas);

module.exports = router;
