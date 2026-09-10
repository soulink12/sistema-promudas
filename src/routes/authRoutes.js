const express = require('express');
const authController = require('../controllers/authController');
const { criarLimiteTentativas } = require('../middlewares/limiteTentativas');

const router = express.Router();

// Endpoints públicos: sem limite, dá para varrer senhas à vontade — e cada
// tentativa custa um hash bcrypt, então também serve de DoS barato.
const limiteLogin = criarLimiteTentativas({
    janelaMs: 5 * 60 * 1000,
    maxTentativas: 10,
    mensagem: 'Muitas tentativas de login.',
});

const limiteRegistro = criarLimiteTentativas({
    janelaMs: 60 * 60 * 1000,
    maxTentativas: 5,
    mensagem: 'Muitas tentativas de cadastro.',
});

router.post('/registrar', limiteRegistro, authController.registrar);
router.post('/login', limiteLogin, authController.login);

module.exports = router;