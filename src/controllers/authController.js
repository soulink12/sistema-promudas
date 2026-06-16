const authService = require('../services/authService');

const registrar = async (req, res, next) => {
    try {
        const dados = req.body;
        const novoUsuario = await authService.registrarUsuario(dados);

        res.status(201).json({
            mensagem: 'Usuário criado com sucesso!',
            usuarioId: novoUsuario.id
        });
    } catch (erro) {
        next(erro);
    }
};

const login = async (req, res, next) => {
    try {
        const { email, senha } = req.body;

        // Valida as credenciais através do Service
        const usuario = await authService.validarLogin(email, senha);

        // Gera o token através do Service
        const token = authService.gerarToken(usuario);

        res.status(200).json({
            mensagem: 'Login efetuado com sucesso!',
            token: token,
            usuario: { id: usuario.id, nome: usuario.nome }
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    registrar,
    login
};
