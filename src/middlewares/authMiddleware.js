const jwt = require('jsonwebtoken');

const verificarToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    
    if (!authHeader) {
        return res.status(403).json({ erro: 'Nenhum token fornecido. Acesso negado.' });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
        return res.status(403).json({ erro: 'Formato de token inválido.' });
    }

    jwt.verify(token, process.env.JWT_SECRET, (err, usuarioDecodificado) => {
        if (err) {
            return res.status(401).json({ erro: 'Token inválido ou expirado. Faça login novamente.' });
        }

        req.usuarioId = usuarioDecodificado.id;
        next();
    });
};

module.exports = {
    verificarToken
};