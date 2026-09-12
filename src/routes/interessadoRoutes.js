const express = require('express');
const router = express.Router();
const interessadoController = require('../controllers/interessadoController');

router.post('/', interessadoController.criarInteressado);
router.get('/', interessadoController.listarInteressados);
router.get('/:id', interessadoController.buscarInteressado);
router.put('/:id', interessadoController.atualizarInteressado);
router.delete('/:id', interessadoController.eliminarInteressado);

module.exports = router;
