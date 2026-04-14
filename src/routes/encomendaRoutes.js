const express = require('express');
const router = express.Router();
const encomendaController = require('../controllers/encomendaController');

router.post('/', encomendaController.criarEncomenda);
router.get('/', encomendaController.listarEncomendas);
router.put('/:id', encomendaController.atualizarEncomenda); // UPDATE
router.delete('/:id', encomendaController.eliminarEncomenda); // DELETE

module.exports = router;