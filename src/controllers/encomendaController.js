const encomendaService = require('../services/encomendaService');

const criarEncomenda = async (req, res) => {
    try {
        const dados = req.body;
        
        // Validação: precisa do cliente e de pelo menos um item na lista
        if (!dados.cliente_id || !dados.itens || !Array.isArray(dados.itens) || dados.itens.length === 0) {
            return res.status(400).json({ 
                erro: 'O ID do cliente e a lista de itens (com variedade e quantidade) são obrigatórios.' 
            });
        }

        const novaEncomenda = await encomendaService.criarEncomenda(dados);
        return res.status(201).json({ 
            mensagem: 'Encomenda e itens registrados com sucesso!', 
            data: novaEncomenda 
        });
        
    } catch (error) {
        console.error('Erro ao criar encomenda:', error);
        return res.status(500).json({ erro: 'Erro interno ao registrar encomenda.' });
    }
};

const listarEncomendas = async (req, res) => {
    try {
        const encomendas = await encomendaService.listarEncomendas();
        return res.status(200).json(encomendas);
    } catch (error) {
        console.error('Erro ao buscar encomendas:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const atualizarEncomenda = async (req, res) => {
  try {
    const encomenda = await encomendaService.atualizarEncomenda(req.params.id, req.body);
    res.json(encomenda);
  } catch (error) {
    res.status(500).json({ error: "Erro ao atualizar encomenda" });
  }
};

const eliminarEncomenda = async (req, res) => {
  try {
    await encomendaService.eliminarEncomenda(req.params.id);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: "Erro ao eliminar encomenda" });
  }
};

module.exports = {
    criarEncomenda,
    listarEncomendas,
    atualizarEncomenda,
    eliminarEncomenda
};