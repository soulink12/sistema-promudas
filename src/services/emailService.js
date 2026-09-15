const { Resend } = require('resend');
const BusinessError = require('../utils/BusinessError');
const { nomeArquivoAscii } = require('../utils/contentDisposition');

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

// Aviso no fim de todo e-mail enviado ao cliente. A caixa de envio hoje é só
// de saída; quando passar a receber respostas, este texto sai.
const AVISO_AUTOMATICO =
    'Este é um e-mail automático e esta caixa não recebe respostas. '
    + 'Para falar com a gente, procure o Viveiro ProMudas pelos canais de atendimento.';

// Catálogo dos eventos que disparam e-mail.
//   `titulo`  — assunto da mensagem (o número do documento é acrescentado).
//   `cliente` — quando true, o cliente do documento recebe além da
//               administração (EMAIL_NOTIFICACAO_PEDIDOS).
//   `frase`   — texto para o cliente; recebe o número do documento.
const EVENTOS = {
    pedidoCriado: {
        titulo: 'Confirmação de pedido',
        cliente: false,
        frase: (numero) => `Seu pedido ${numero} foi registrado.`,
    },
    pedidoAlterado: {
        titulo: 'Atualização de pedido',
        cliente: true,
        frase: (numero) => `Seu pedido ${numero} foi atualizado.`,
    },
    pedidoPagamento: {
        titulo: 'Pagamento de pedido realizado',
        cliente: true,
        frase: (numero) => `Registramos um pagamento no seu pedido ${numero}.`,
    },
    orcamentoAprovado: {
        titulo: 'Aprovação de orçamento',
        cliente: true,
        frase: (numero) => `Seu orçamento foi aprovado e gerou o pedido ${numero}.`,
    },
    orcamentoCriado: {
        titulo: 'Pedido de orçamento',
        cliente: false,
        frase: (numero) => `Seu orçamento ${numero} foi registrado.`,
    },
    orcamentoAlterado: {
        titulo: 'Alteração de orçamento',
        cliente: false,
        frase: (numero) => `Seu orçamento ${numero} foi atualizado.`,
    },
    orcamentoRecusado: {
        titulo: 'Recusa de orçamento',
        cliente: false,
        frase: (numero) => `Seu orçamento ${numero} foi recusado.`,
    },
    // Envio manual, pelo botão "Enviar por e-mail" — só vai para o cliente.
    pedidoManual: {
        titulo: 'Confirmação de pedido',
        cliente: true,
        frase: (numero) => `Segue o recibo do seu pedido ${numero}.`,
    },
    orcamentoManual: {
        titulo: 'Pedido de orçamento',
        cliente: true,
        frase: (numero) => `Segue o seu orçamento ${numero}.`,
    },
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
                // Nome de anexo com acento chega corrompido no cliente de
                // e-mail (MIME exige codificação própria para não-ASCII), então
                // vai sem acento: "Orçamento #12.pdf" → "Orcamento #12.pdf".
                filename: nomeArquivoAscii(nomeArquivo),
                content: anexoBuffer,
            },
        ],
    }, {
        // O SDK da Resend manda `Content-Type: application/json` sem charset.
        // Sem essa declaração, os bytes UTF-8 do assunto e do corpo podem ser
        // reinterpretados como Latin-1 e "João" chega como "JoÃ£o".
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
    });

    if (error) {
        throw new BusinessError(`Falha ao enviar e-mail: ${error.message}`, 502);
    }
};

const corpoParaCliente = (nomeCliente, frase) =>
    `Olá, ${nomeCliente}!\n\n${frase}\n\nO documento segue em anexo.\n\n${AVISO_AUTOMATICO}`;

// Dispara os e-mails de um evento: sempre para a administração
// (EMAIL_NOTIFICACAO_PEDIDOS, quando configurada) e, nos eventos marcados com
// `cliente: true`, também para o cliente do documento.
//
// Recebe o PDF já gerado (`documento`, de gerarPedidoPDF/gerarOrcamentoPDF) —
// quem chama gera uma vez só e reaproveita entre e-mail e outros canais (ex.:
// telegramService.notificarEvento), em vez de cada canal gerar o seu. Cada
// destinatário falha de forma independente e sem derrubar o outro — e-mail é
// best-effort, nunca pode quebrar o registro do pedido/pagamento em si.
const notificarEvento = async ({ evento, documento, numero }) => {
    const config = EVENTOS[evento];
    if (!config) throw new Error(`Evento de e-mail desconhecido: ${evento}`);

    const emailAdmin = process.env.EMAIL_NOTIFICACAO_PEDIDOS;
    if (!emailAdmin && !config.cliente) return;

    const { entidade, buffer, nomeArquivo } = documento;
    const nomeCliente = entidade.clientes?.nome ?? 'cliente';
    const assunto = `${config.titulo} ${numero}`;

    if (emailAdmin) {
        try {
            await enviarPdfPorEmail({
                destinatario: emailAdmin,
                assunto: `${assunto} — ${nomeCliente}`,
                // Texto neutro: `frase` é escrita para o cliente ("seu pedido"),
                // o que soa errado numa notificação interna.
                corpo: `${config.titulo}.\n\nDocumento: ${numero}\nCliente: ${nomeCliente}`,
                anexoBuffer: buffer,
                nomeArquivo,
            });
        } catch (erro) {
            console.error('Falha ao enviar notificação interna:', erro);
        }
    }

    const emailCliente = entidade.clientes?.email;
    if (config.cliente && emailCliente) {
        try {
            await enviarPdfPorEmail({
                destinatario: emailCliente,
                assunto,
                corpo: corpoParaCliente(nomeCliente, config.frase(numero)),
                anexoBuffer: buffer,
                nomeArquivo,
            });
        } catch (erro) {
            console.error('Falha ao enviar e-mail ao cliente:', erro);
        }
    }
};

// Envio manual pelo botão "Enviar por e-mail": ao contrário do automático,
// aqui a ausência de e-mail no cadastro é erro visível para o operador, e uma
// falha no envio precisa aparecer na tela.
const enviarDocumentoPorEmail = async ({ id, evento, gerarPDF, formatarNumero }) => {
    const config = EVENTOS[evento];
    if (!config) throw new Error(`Evento de e-mail desconhecido: ${evento}`);

    const { entidade, buffer, nomeArquivo } = await gerarPDF(id);
    if (!entidade.clientes?.email) {
        throw new BusinessError('Este cliente não tem e-mail cadastrado.');
    }

    const numero = formatarNumero(entidade);
    await enviarPdfPorEmail({
        destinatario: entidade.clientes.email,
        assunto: `${config.titulo} ${numero}`,
        corpo: corpoParaCliente(entidade.clientes.nome, config.frase(numero)),
        anexoBuffer: buffer,
        nomeArquivo,
    });
};

module.exports = {
    enviarPdfPorEmail,
    notificarEvento,
    enviarDocumentoPorEmail,
    EVENTOS,
};
