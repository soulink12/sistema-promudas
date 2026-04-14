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

const atualizarVariedade = async (req, res) => {
  try {
    const variedade = await variedadeService.atualizarVariedade(req.params.id, req.body);
    res.json(variedade);
  } catch (error) {
    res.status(500).json({ error: "Erro ao atualizar variedade" });
  }
};

const eliminarVariedade = async (req, res) => {
  try {
    await variedadeService.eliminarVariedade(req.params.id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: "Erro ao eliminar variedade" });
  }
};

module.exports = {
    criarVariedade,
    listarVariedades,
    atualizarVariedade,
    eliminarVariedade
};