const { Resend } = require('resend');
const BusinessError = require('../utils/BusinessError');

let resend = null;
const getResend = () => {
    if (!resend) {
        if (!process.env.RESEND_API_KEY) {
            throw new BusinessError('Envio de e-mail não configurado no servidor.', 500);
        }
        resend = new Resend(process.env.RESEND_API_KEY);
    }
    return resend;
};

// Envia um PDF (buffer) por e-mail como anexo. Lança BusinessError se a
// Resend recusar o envio (ex.: domínio do remetente não verificado).
const enviarPdfPorEmail = async ({ destinatario, assunto, corpo, anexoBuffer, nomeArquivo }) => {
    const { error } = await getResend().emails.send({
        from: process.env.EMAIL_REMETENTE,
        to: destinatario,
        subject: assunto,
        text: corpo,
        attachments: [
            {
                filename: nomeArquivo,
                content: anexoBuffer,
            },
        ],
    });

    if (error) {
        throw new BusinessError(`Falha ao enviar e-mail: ${error.message}`, 502);
    }
};

// Notifica o e-mail interno (EMAIL_NOTIFICACAO_PEDIDOS) de um pedido/orçamento
// novo ou alterado, anexando o PDF. Não lança erro — é uma notificação
// interna best-effort, uma falha nela não pode derrubar a criação/edição do
// pedido/orçamento em si. No-op se a variável não estiver configurada.
const notificarPedidoOuOrcamento = async ({ assunto, corpo, anexoBuffer, nomeArquivo }) => {
    const destinatario = process.env.EMAIL_NOTIFICACAO_PEDIDOS;
    if (!destinatario) return;

    try {
        await enviarPdfPorEmail({ destinatario, assunto, corpo, anexoBuffer, nomeArquivo });
    } catch (erro) {
        console.error('Falha ao enviar notificação interna de pedido/orçamento:', erro);
    }
};

// Sequência comum a pedido e orçamento: gera o PDF (`gerarPDF`, que resolve
// com { buffer, nomeArquivo, entidade }) e dispara a notificação interna
// best-effort. `rotulo` é "Pedido"/"Orçamento". Silencioso quando o
// documento não é mais encontrado (ex.: apagado logo após); outros erros
// (falha ao gerar o PDF, etc.) sobem para o `.catch` do chamador.
const notificarDocumentoPorEmail = async ({ id, tipo, gerarPDF, formatarNumero, rotulo }) => {
    if (!process.env.EMAIL_NOTIFICACAO_PEDIDOS) return;

    let resultado;
    try {
        resultado = await gerarPDF(id);
    } catch (erro) {
        if (erro.status === 404) return;
        throw erro;
    }

    const { entidade, buffer, nomeArquivo } = resultado;
    const numero = formatarNumero(entidade);
    const nomeCliente = entidade.clientes?.nome ?? 'cliente';

    await notificarPedidoOuOrcamento({
        assunto: `${rotulo} ${numero} ${tipo} — ${nomeCliente}`,
        corpo: `O ${rotulo.toLowerCase()} ${numero} (${nomeCliente}) foi ${tipo} no sistema.`,
        anexoBuffer: buffer,
        nomeArquivo,
    });
};

// Sequência comum a pedido e orçamento: gera o PDF, exige que o cliente
// tenha e-mail cadastrado e envia. `descricaoDocumento` completa a frase
// "Segue em anexo <descricaoDocumento> na Viveiro Promudas.".
const enviarDocumentoPorEmail = async ({ id, gerarPDF, formatarNumero, rotulo, descricaoDocumento }) => {
    const { entidade, buffer, nomeArquivo } = await gerarPDF(id);
    if (!entidade.clientes?.email) {
        throw new BusinessError('Este cliente não tem e-mail cadastrado.');
    }

    await enviarPdfPorEmail({
        destinatario: entidade.clientes.email,
        assunto: `${rotulo} ${formatarNumero(entidade)} — Viveiro Promudas`,
        corpo: `Olá, ${entidade.clientes.nome}!\n\nSegue em anexo ${descricaoDocumento} na Viveiro Promudas.\n\nQualquer dúvida, estamos à disposição.`,
        anexoBuffer: buffer,
        nomeArquivo,
    });
};

module.exports = {
    enviarPdfPorEmail,
    notificarPedidoOuOrcamento,
    notificarDocumentoPorEmail,
    enviarDocumentoPorEmail,
};
