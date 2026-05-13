const prisma = require('../config/database');
const bcrypt = require('bcrypt');

const registrarUsuario = async (dadosUsuario) => {
    // Verifica se o email já existe no banco
    const usuarioExistente = await prisma.usuarios.findUnique({
        where: { email: dadosUsuario.email }
    });
    
    if (usuarioExistente) {
        throw new Error('Este email já está em uso.');
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
        throw new Error('Email ou senha inválidos.');
    }

    // Compara a senha
    const senhaValida = await bcrypt.compare(senha, usuario.senha_hash);
    if (!senhaValida) {
        throw new Error('Email ou senha inválidos.');
    }

    return usuario;
};

module.exports = {
    registrarUsuario,
    validarLogin
};