const variedadeService = require('../services/variedadeService');

const criarVariedade = async (req, res) => {
    try {
        const dados = req.body;
        
        if (!dados.nome) {
            return res.status(400).json({ erro: 'O nome da variedade é obrigatório.' });
        }

        const novoId = await variedadeService.criarVariedade(dados);
        return res.status(201).json({ mensagem: 'Variedade cadastrada com sucesso!', id: novoId });
        
    } catch (error) {
        console.error('Erro ao criar variedade:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const listarVariedades = async (req, res) => {
    try {
        const variedades = await variedadeService.listarVariedades();
        return res.status(200).json(variedades);
    } catch (error) {
        console.error('Erro ao buscar variedades:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

module.exports = {
    criarVariedade,
    listarVariedades
};