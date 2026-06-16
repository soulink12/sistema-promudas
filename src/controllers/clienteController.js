const clienteService = require('../services/clienteService');

const criarCliente = async (req, res, next) => {
    try {
        const dados = req.body;

        // Uma validação simples para garantir que não criem cliente sem nome
        if (!dados.nome) {
            return res.status(400).json({ erro: 'O campo nome é obrigatório.' });
        }

        const novoId = await clienteService.criarCliente(dados);
        return res.status(201).json({ mensagem: 'Cliente criado com sucesso!', id: novoId });

    } catch (erro) {
        next(erro);
    }
};

const listarClientes = async (req, res, next) => {
    try {
        const clientes = await clienteService.listarClientes({ busca: req.query.busca });
        return res.status(200).json(clientes);
    } catch (erro) {
        next(erro);
    }
};

const buscarCliente = async (req, res, next) => {
    try {
        const cliente = await clienteService.buscarCliente(req.params.id);
        if (!cliente) return res.status(404).json({ erro: 'Cliente não encontrado.' });
        return res.status(200).json(cliente);
    } catch (erro) {
        next(erro);
    }
};

const atualizarCliente = async (req, res, next) => {
    try {
        const cliente = await clienteService.atualizarCliente(req.params.id, req.body);
        res.json(cliente);
    } catch (erro) {
        next(erro);
    }
};

const eliminarCliente = async (req, res, next) => {
    try {
        await clienteService.eliminarCliente(req.params.id);
        res.status(204).send();
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarCliente,
    listarClientes,
    buscarCliente,
    atualizarCliente,
    eliminarCliente
};
