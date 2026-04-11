const clienteService = require('../services/clienteService');

const criarCliente = async (req, res) => {
    try {
        const dados = req.body;
        
        // Uma validação simples para garantir que não criem cliente sem nome
        if (!dados.nome) {
            return res.status(400).json({ erro: 'O campo nome é obrigatório.' });
        }

        const novoId = await clienteService.criarCliente(dados);
        return res.status(201).json({ mensagem: 'Cliente criado com sucesso!', id: novoId });
        
    } catch (error) {
        console.error('Erro ao criar cliente:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const listarClientes = async (req, res) => {
    try {
        const clientes = await clienteService.listarClientes();
        return res.status(200).json(clientes);
    } catch (error) {
        console.error('Erro ao buscar clientes:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

module.exports = {
    criarCliente,
    listarClientes
};