const BusinessError = require('./BusinessError');

// Converte um valor recebido na requisição em um Date válido para o Prisma.
// O Prisma valida strings de data de forma estrita (rejeita, p.ex., ISO com
// microssegundos e sem "Z", como o `DateTime.toIso8601String()` do Dart) e
// estoura 500. Normalizando aqui, a data passa a ser aceita quando o JS a
// entende e, quando é realmente inválida, lançamos BusinessError (400) com
// mensagem clara em vez de um 500 genérico.
//
// Mantém null/undefined intactos (campos de data opcionais não são tocados).
const parseData = (valor, campo = 'data') => {
    if (valor === null || valor === undefined) return valor;

    const data = valor instanceof Date ? valor : new Date(valor);
    if (isNaN(data.getTime())) {
        throw new BusinessError(`Data inválida no campo "${campo}".`);
    }
    return data;
};

// Retorna uma cópia de [dados] com os [campos] de data convertidos via
// parseData. Só toca nos campos presentes (undefined é ignorado).
const normalizarDatas = (dados, campos) => {
    const saida = { ...dados };
    for (const campo of campos) {
        if (saida[campo] !== undefined) {
            saida[campo] = parseData(saida[campo], campo);
        }
    }
    return saida;
};

module.exports = { parseData, normalizarDatas };
