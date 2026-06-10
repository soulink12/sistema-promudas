const pedidoService = require('../services/pedidoService');
const pdfService = require('../services/pdfService');

const criarPedido = async (req, res) => {
    try {
        const dados = req.body;

        if (!dados.cliente_id || !dados.itens || !Array.isArray(dados.itens) || dados.itens.length === 0) {
            return res.status(400).json({
                erro: 'O ID do cliente e a lista de itens (com produto e quantidade) são obrigatórios.'
            });
        }

        const novoPedido = await pedidoService.criarPedido(dados);
        return res.status(201).json({
            mensagem: 'Pedido registrado com sucesso!',
            data: novoPedido
        });

    } catch (error) {
        console.error('Erro ao criar pedido:', error);
        return res.status(500).json({ erro: 'Erro interno ao registrar pedido.' });
    }
};

const buscarPedido = async (req, res) => {
    try {
        const pedido = await pedidoService.buscarPedido(req.params.id);
        if (!pedido) return res.status(404).json({ erro: 'Pedido não encontrado.' });
        res.json(pedido);
    } catch (error) {
        console.error('Erro ao buscar pedido:', error);
        res.status(500).json({ erro: 'Erro ao buscar pedido.' });
    }
};

const listarPedidos = async (req, res) => {
    try {
        const { cliente, statusRetirada } = req.query;
        const filtros = {};
        if (cliente) filtros.cliente = cliente;
        if (statusRetirada) filtros.statusRetirada = statusRetirada;
        const pedidos = await pedidoService.listarPedidos(filtros);
        return res.status(200).json(pedidos);
    } catch (error) {
        console.error('Erro ao buscar pedidos:', error);
        return res.status(500).json({ erro: 'Erro interno do servidor.' });
    }
};

const atualizarPedido = async (req, res) => {
    try {
        const pedido = await pedidoService.atualizarPedido(req.params.id, req.body);
        res.json({ ...pedido, creditoGerado: pedido.creditoGerado ?? 0 });
    } catch (error) {
        console.error('Erro ao atualizar pedido:', error);
        res.status(error.status || 500).json({ erro: error.message || 'Erro ao atualizar pedido.' });
    }
};

const eliminarPedido = async (req, res) => {
    try {
        await pedidoService.eliminarPedido(req.params.id);
        res.status(204).send();
    } catch (error) {
        res.status(500).json({ erro: 'Erro ao eliminar pedido.' });
    }
};

const gerarPDF = async (req, res) => {
    try {
        const buffer = await pdfService.gerarPedidoPDF(req.params.id);
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename="pedido_${req.params.id}.pdf"`);
        res.setHeader('Content-Length', buffer.length);
        res.send(buffer);
    } catch (error) {
        console.error('Erro ao gerar PDF:', error);
        res.status(error.status || 500).json({ erro: error.message || 'Erro ao gerar PDF do pedido.' });
    }
};

module.exports = {
    criarPedido,
    listarPedidos,
    buscarPedido,
    atualizarPedido,
    eliminarPedido,
    gerarPDF
};
