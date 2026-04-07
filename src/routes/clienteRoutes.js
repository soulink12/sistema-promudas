const express = require('express');
const router = express.Router();
const clienteController = require('../controllers/clienteController');

// Rota para criar um cliente (POST)
router.post('/', clienteController.criarCliente);

// Rota para listar os clientes (GET)
router.get('/', clienteController.listarClientes);

module.exports = router;