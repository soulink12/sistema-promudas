const express = require('express');
const router = express.Router();
const orcamentoController = require('../controllers/orcamentoController');

router.post('/', orcamentoController.criarOrcamento);
router.get('/', orcamentoController.listarOrcamentos);
router.get('/:id/pdf', orcamentoController.gerarPDF);
router.post('/:id/enviar-email', orcamentoController.enviarEmail);
router.post('/:id/aprovar', orcamentoController.aprovarOrcamento);
router.post('/:id/recusar', orcamentoController.recusarOrcamento);
router.get('/:id', orcamentoController.buscarOrcamento);
router.put('/:id', orcamentoController.atualizarOrcamento);
router.delete('/:id', orcamentoController.eliminarOrcamento);

module.exports = router;
