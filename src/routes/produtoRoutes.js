const express = require('express');
const router = express.Router();
const produtoController = require('../controllers/produtoController');

router.post('/', produtoController.criarProduto);
router.get('/', produtoController.listarProdutos);
router.put('/:id', produtoController.atualizarProduto);
router.delete('/:id', produtoController.eliminarProduto);

module.exports = router;
