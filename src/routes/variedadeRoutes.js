const express = require('express');
const router = express.Router();
const variedadeController = require('../controllers/variedadeController');

router.post('/', variedadeController.criarProduto);
router.get('/', variedadeController.listarProdutos);
router.put('/:id', variedadeController.atualizarProduto);
router.delete('/:id', variedadeController.eliminarProduto);

module.exports = router;
