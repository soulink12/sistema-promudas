// Cabecalhos HTTP so aceitam ISO-8859-1, entao um filename="Orcamento..." com
// acento vira lixo no cliente (Node envia o byte Latin-1, mas os clientes HTTP
// em geral decodificam o header como UTF-8). RFC 6266/5987 resolve isso com
// um `filename*=UTF-8''<percent-encoded>` ao lado de um `filename=` puro
// ASCII de fallback (removendo os acentos) para clientes que nao leem o
// parametro estendido.
const DIACRITICOS = /[̀-ͯ]/g;

// Versao do nome sem acento e sem caractere fora do ASCII imprimivel.
// Usada como fallback no header HTTP e como nome do anexo de e-mail, onde
// nome nao-ASCII em MIME chega corrompido no cliente de e-mail.
const nomeArquivoAscii = (nomeArquivo) => String(nomeArquivo ?? '')
    .normalize('NFD')
    .replace(DIACRITICOS, '')
    .replace(/[^\x20-\x7E]/g, '_');

const contentDisposition = (nomeArquivo) => {
    const asciiFallback = nomeArquivoAscii(nomeArquivo);
    const utf8Encoded = encodeURIComponent(nomeArquivo);
    return `attachment; filename="${asciiFallback}"; filename*=UTF-8''${utf8Encoded}`;
};

module.exports = { contentDisposition, nomeArquivoAscii };
