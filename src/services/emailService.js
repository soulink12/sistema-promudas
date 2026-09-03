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

module.exports = { enviarPdfPorEmail };
