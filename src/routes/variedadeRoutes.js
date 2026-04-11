const express = require('express');
const router = express.Router();
const variedadeController = require('../controllers/variedadeController');

router.post('/', variedadeController.criarVariedade);
router.get('/', variedadeController.listarVariedades);

module.exports = router;