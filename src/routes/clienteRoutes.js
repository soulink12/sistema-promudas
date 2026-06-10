const express = require('express');
const router = express.Router();
const clienteController = require('../controllers/clienteController');

// Rota para criar um cliente (POST)
router.post('/', clienteController.criarCliente);

// Rota para listar os clientes (GET)
router.get('/', clienteController.listarClientes);

// Rota para buscar um cliente específico (GET)
router.get('/:id', clienteController.buscarCliente);

router.put('/:id', clienteController.atualizarCliente); // UPDATE
router.delete('/:id', clienteController.eliminarCliente); // DELETE

module.exports = router;