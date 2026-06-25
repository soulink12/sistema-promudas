const express = require('express');
const router = express.Router();
const temporadaController = require('../controllers/temporadaController');

router.get('/', temporadaController.listarTemporadas);
router.post('/', temporadaController.criarTemporada);
router.put('/:id/ativar', temporadaController.ativarTemporada);

module.exports = router;
