const express = require('express');
const router = express.Router();
const locaisEntregaController = require('../controllers/locaisEntregaController');

router.get('/', locaisEntregaController.listarLocais);

module.exports = router;
