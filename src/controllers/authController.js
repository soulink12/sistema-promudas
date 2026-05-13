const authService = require('../services/authService');
const jwt = require('jsonwebtoken');

const registrar = async (req, res) => {
    try {
        const dados = req.body;
        const novoUsuario = await authService.registrarUsuario(dados);
        
        res.status(201).json({ 
            mensagem: 'Usuário criado com sucesso!', 
            usuarioId: novoUsuario.id 
        });
    } catch (error) {
        console.error(error);
        // Se for o erro de email duplicado que lançámos no Service, devolve 400
        res.status(400).json({ erro: error.message || 'Erro interno ao registrar usuário.' });
    }
};

const login = async (req, res) => {
    try {
        const { email, senha } = req.body;
        
        // Valida as credenciais através do Service
        const usuario = await authService.validarLogin(email, senha);

        // Gera o Token
        const token = jwt.sign(
            { id: usuario.id, email: usuario.email },
            process.env.JWT_SECRET,
            { expiresIn: '8h' }
        );

        res.status(200).json({
            mensagem: 'Login efetuado com sucesso!',
            token: token,
            usuario: { id: usuario.id, nome: usuario.nome }
        });
    } catch (error) {
        console.error(error);
        res.status(401).json({ erro: error.message || 'Erro interno ao fazer login.' });
    }
};

module.exports = {
    registrar,
    login
};