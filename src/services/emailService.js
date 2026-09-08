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

module.exports = { enviarPdfPorEmail, notificarPedidoOuOrcamento };
