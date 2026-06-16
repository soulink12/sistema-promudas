const prisma = require('../config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const BusinessError = require('../utils/BusinessError');

const registrarUsuario = async (dadosUsuario) => {
    // Verifica se o email já existe no banco
    const usuarioExistente = await prisma.usuarios.findUnique({
        where: { email: dadosUsuario.email }
    });
    
    if (usuarioExistente) {
        throw new BusinessError('Este email já está em uso.', 400);
    }

    // Criptografa a senha
    const salt = await bcrypt.genSalt(10);
    const senha_hash = await bcrypt.hash(dadosUsuario.senha, salt);

    // Cria o usuário
    const novoUsuario = await prisma.usuarios.create({
        data: {
            nome: dadosUsuario.nome,
            email: dadosUsuario.email,
            senha_hash: senha_hash
        }
    });

    return novoUsuario;
};

const validarLogin = async (email, senha) => {
    // Busca o usuário
    const usuario = await prisma.usuarios.findUnique({
        where: { email }
    });
    
    if (!usuario || !usuario.ativo) {
        throw new BusinessError('Email ou senha inválidos.', 401);
    }

    // Compara a senha
    const senhaValida = await bcrypt.compare(senha, usuario.senha_hash);
    if (!senhaValida) {
        throw new BusinessError('Email ou senha inválidos.', 401);
    }

    return usuario;
};

// Gera o token JWT de um usuário autenticado (payload, segredo e expiração padrão).
const gerarToken = (usuario) => {
    return jwt.sign(
        { id: usuario.id, email: usuario.email },
        process.env.JWT_SECRET,
        { expiresIn: '8h' }
    );
};

module.exports = {
    registrarUsuario,
    validarLogin,
    gerarToken
};