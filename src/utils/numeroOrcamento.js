// Formata o número de exibição do orçamento: sempre "#id" — orçamento usa
// numeração própria simples (sem temporada), diferente do pedido.
const formatarNumeroOrcamento = (orcamento) => {
    if (!orcamento) return '';
    return `#${orcamento.id}`;
};

module.exports = { formatarNumeroOrcamento };
