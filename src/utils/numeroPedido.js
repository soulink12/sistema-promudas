// Formata o número de exibição do pedido a partir da temporada.
// Ex.: { temporada_ano: 2026, numero_temporada: 1 } => "26-1".
// Sem temporada (pedidos antigos/importados sem número), cai no id: "#123".
const formatarNumeroPedido = (pedido) => {
    if (!pedido) return '';
    const { temporada_ano, numero_temporada, id } = pedido;
    if (temporada_ano != null && numero_temporada != null) {
        const ano = String(temporada_ano % 100).padStart(2, '0');
        return `${ano}-${numero_temporada}`;
    }
    return `#${id}`;
};

module.exports = { formatarNumeroPedido };
