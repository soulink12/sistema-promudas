const orcamentoService = require('../services/orcamentoService');
const pdfService = require('../services/pdfService');

const criarOrcamento = async (req, res, next) => {
    try {
        const dados = req.body;

        if (!dados.cliente_id || !dados.itens || !Array.isArray(dados.itens) || dados.itens.length === 0) {
            return res.status(400).json({
                erro: 'O ID do cliente e a lista de itens (com produto e quantidade) são obrigatórios.'
            });
        }

        const novoOrcamento = await orcamentoService.criarOrcamento(dados);
        return res.status(201).json({
            mensagem: 'Orçamento registrado com sucesso!',
            data: novoOrcamento
        });
    } catch (erro) {
        next(erro);
    }
};

const buscarOrcamento = async (req, res, next) => {
    try {
        const orcamento = await orcamentoService.buscarOrcamento(req.params.id);
        if (!orcamento) return res.status(404).json({ erro: 'Orçamento não encontrado.' });
        res.json(orcamento);
    } catch (erro) {
        next(erro);
    }
};

const listarOrcamentos = async (req, res, next) => {
    try {
        const { cliente, status, de, ate, numero } = req.query;
        const filtros = {};
        if (cliente) filtros.cliente = cliente;
        if (status) filtros.status = status;
        if (de) filtros.de = de;
        if (ate) filtros.ate = ate;
        if (numero) filtros.numero = numero;
        const orcamentos = await orcamentoService.listarOrcamentos(filtros);
        return res.status(200).json(orcamentos);
    } catch (erro) {
        next(erro);
    }
};

const atualizarOrcamento = async (req, res, next) => {
    try {
        const orcamento = await orcamentoService.atualizarOrcamento(req.params.id, req.body);
        res.json(orcamento);
    } catch (erro) {
        next(erro);
    }
};

const eliminarOrcamento = async (req, res, next) => {
    try {
        await orcamentoService.eliminarOrcamento(req.params.id);
        res.status(204).send();
    } catch (erro) {
        next(erro);
    }
};

const gerarPDF = async (req, res, next) => {
    try {
        const { buffer, nomeArquivo } = await pdfService.gerarOrcamentoPDF(req.params.id);
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename="${nomeArquivo}"`);
        res.setHeader('Content-Length', buffer.length);
        res.send(buffer);
    } catch (erro) {
        next(erro);
    }
};

const enviarEmail = async (req, res, next) => {
    try {
        await orcamentoService.enviarOrcamentoPorEmail(req.params.id);
        return res.status(200).json({ mensagem: 'E-mail enviado com sucesso!' });
    } catch (erro) {
        next(erro);
    }
};

const aprovarOrcamento = async (req, res, next) => {
    try {
        const orcamento = await orcamentoService.aprovarOrcamento(req.params.id);
        res.json(orcamento);
    } catch (erro) {
        next(erro);
    }
};

const recusarOrcamento = async (req, res, next) => {
    try {
        const orcamento = await orcamentoService.recusarOrcamento(req.params.id);
        res.json(orcamento);
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    criarOrcamento,
    listarOrcamentos,
    buscarOrcamento,
    atualizarOrcamento,
    eliminarOrcamento,
    gerarPDF,
    enviarEmail,
    aprovarOrcamento,
    recusarOrcamento
};
