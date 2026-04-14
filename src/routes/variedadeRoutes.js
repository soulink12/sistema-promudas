const express = require('express');
const router = express.Router();
const variedadeController = require('../controllers/variedadeController');

router.post('/', variedadeController.criarVariedade);
router.get('/', variedadeController.listarVariedades);
router.put('/:id', variedadeController.atualizarVariedade); // UPDATE
router.delete('/:id', variedadeController.eliminarVariedade); // DELETE

module.exports = router;