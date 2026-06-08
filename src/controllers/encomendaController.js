const encomendaService = require('../services/encomendaService');

const criarPedido = async (req, res) => {
    try {
        const dados = req.body;

        if (!dados.cliente_id || !dados.itens || !Array.isArray(dados.itens) || dados.itens.length === 0) {
            return res.status(400).json({
                erro: 'O ID do cliente e a lista de itens (com produto e quantidade) são obrigatórios.'
            });
        }

        const novoPedido = await encomendaService.criarPedido(dados);
        return res.status(201).json({
            mensagem: 'Pedido registrado com sucesso!',
            data: novoPedido
        });

    } catch (error) {
        console.error('Erro ao criar pedido:', error);
        return res.status(500).json({ erro: 'Erro interno ao registrar pedido.' });
    }
};

const listarPedidos = async (req, res) => {
    try {
        const pedidos = await encomendaService.listarPedidos();
        return res.status(200).json(pedidos);
    } catch (error) {
        console.error('Erro ao buscar pedidos:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const atualizarPedido = async (req, res) => {
    try {
        const pedido = await encomendaService.atualizarPedido(req.params.id, req.body);
        res.json(pedido);
    } catch (error) {
        res.status(500).json({ erro: 'Erro ao atualizar pedido.' });
    }
};

const eliminarPedido = async (req, res) => {
    try {
        await encomendaService.eliminarPedido(req.params.id);
        res.status(204).send();
    } catch (error) {
        res.status(500).json({ erro: 'Erro ao eliminar pedido.' });
    }
};

module.exports = {
    criarPedido,
    listarPedidos,
    atualizarPedido,
    eliminarPedido
};
