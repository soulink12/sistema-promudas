const pedidoService = require('../services/pedidoService');
const pdfService = require('../services/pdfService');

const criarPedido = async (req, res, next) => {
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

    } catch (erro) {
        next(erro);
    }
};

const buscarPedido = async (req, res, next) => {
    try {
        const pedido = await pedidoService.buscarPedido(req.params.id);
        if (!pedido) return res.status(404).json({ erro: 'Pedido não encontrado.' });
        res.json(pedido);
    } catch (erro) {
        next(erro);
    }
};

const listarPedidos = async (req, res, next) => {
    try {
        const { cliente, statusEntrega, statusPagamento, statusNota, de, ate } = req.query;
        const filtros = {};
        if (cliente) filtros.cliente = cliente;
        if (statusEntrega) filtros.statusEntrega = statusEntrega;
        if (statusPagamento) filtros.statusPagamento = statusPagamento;
        if (statusNota) filtros.statusNota = statusNota;
        if (de) filtros.de = de;
        if (ate) filtros.ate = ate;
        const pedidos = await pedidoService.listarPedidos(filtros);
        return res.status(200).json(pedidos);
    } catch (erro) {
        next(erro);
    }
};

const atualizarPedido = async (req, res, next) => {
    try {
        const pedido = await pedidoService.atualizarPedido(req.params.id, req.body);
        res.json({ ...pedido, creditoGerado: pedido.creditoGerado ?? 0 });
    } catch (erro) {
        next(erro);
    }
};

const eliminarPedido = async (req, res, next) => {
    try {
        await pedidoService.eliminarPedido(req.params.id);
        res.status(204).send();
    } catch (erro) {
        next(erro);
    }
};

const gerarPDF = async (req, res, next) => {
    try {
        const { buffer, nomeArquivo } = await pdfService.gerarPedidoPDF(req.params.id);
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename="${nomeArquivo}"`);
        res.setHeader('Content-Length', buffer.length);
        res.send(buffer);
    } catch (erro) {
        next(erro);
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
