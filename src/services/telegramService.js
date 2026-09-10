const BusinessError = require('../utils/BusinessError');
const { EVENTOS } = require('./emailService');

const TELEGRAM_API = 'https://api.telegram.org';

// Envia um PDF (buffer) como documento no Telegram, com legenda. Silencioso
// quando o bot não está configurado (TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID) —
// mesmo comportamento do e-mail sem EMAIL_NOTIFICACAO_PEDIDOS: notificação é
// um recurso opcional, a ausência de configuração não é erro.
const enviarDocumentoTelegram = async ({ legenda, anexoBuffer, nomeArquivo }) => {
    const token = process.env.TELEGRAM_BOT_TOKEN;
    const chatId = process.env.TELEGRAM_CHAT_ID;
    if (!token || !chatId) return;

    const form = new FormData();
    form.append('chat_id', chatId);
    form.append('caption', legenda);
    form.append('document', new Blob([anexoBuffer], { type: 'application/pdf' }), nomeArquivo);

    const resposta = await fetch(`${TELEGRAM_API}/bot${token}/sendDocument`, {
        method: 'POST',
        body: form,
    });
    const resultado = await resposta.json();

    if (!resultado.ok) {
        throw new BusinessError(`Falha ao enviar Telegram: ${resultado.description}`, 502);
    }
};

// Dispara a notificação de um evento no Telegram, reaproveitando o catálogo
// de eventos do e-mail (emailService.EVENTOS) para o título. Só existe o
// canal "administração" — ao contrário do e-mail, não há chat_id de cliente
// cadastrado, então o `cliente: true` de alguns eventos não se aplica aqui.
//
// `documento` é o resultado já resolvido de gerarPedidoPDF/gerarOrcamentoPDF
// (`{ entidade, buffer, nomeArquivo }`) — gerado uma única vez e reaproveitado
// também pelo e-mail, para não gerar o PDF duas vezes por evento. Best-effort:
// nunca deve derrubar o registro do pedido/pagamento em si.
const notificarEvento = async ({ evento, documento, numero }) => {
    if (!process.env.TELEGRAM_BOT_TOKEN || !process.env.TELEGRAM_CHAT_ID) return;

    const config = EVENTOS[evento];
    if (!config) throw new Error(`Evento de Telegram desconhecido: ${evento}`);

    const { buffer, nomeArquivo, entidade } = documento;
    const nomeCliente = entidade.clientes?.nome ?? 'cliente';

    await enviarDocumentoTelegram({
        legenda: `${config.titulo}\n\nDocumento: ${numero}\nCliente: ${nomeCliente}`,
        anexoBuffer: buffer,
        nomeArquivo,
    });
};

module.exports = {
    enviarDocumentoTelegram,
    notificarEvento,
};
