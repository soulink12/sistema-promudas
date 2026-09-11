const express = require('express');
const router = express.Router();
const logController = require('../controllers/logController');

// Rotas estáticas antes de "/:id", senão "/erros"/"/exportar" seriam capturadas por ele.
router.get('/exportar', logController.exportarAtividades);
router.get('/erros', logController.listarErros);
router.get('/erros/:id', logController.buscarErro);
router.get('/:id', logController.buscarAtividade);
router.get('/', logController.listarAtividades);

module.exports = router;
