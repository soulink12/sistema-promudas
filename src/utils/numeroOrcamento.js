// Formata o número de exibição do orçamento: "O{AA}-{N}" (temporada + número
// sequencial dentro dela, mesmo esquema do pedido — ver numeroPedido.js —
// mas com o prefixo "O" pra diferenciar visualmente). Cai para "#id" quando
// o orçamento não tem temporada (nenhuma temporada ativa no momento em que
// foi criado).
const formatarNumeroOrcamento = (orcamento) => {
    if (!orcamento) return '';
    const { temporada_ano, numero_temporada, id } = orcamento;
    if (temporada_ano != null && numero_temporada != null) {
        const ano = String(temporada_ano % 100).padStart(2, '0');
        return `O${ano}-${numero_temporada}`;
    }
    return `#${id}`;
};

module.exports = { formatarNumeroOrcamento };
