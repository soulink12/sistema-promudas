// Formatadores puros reutilizados em todo o app (moeda e data/hora).

/// Formata um valor monetário como `R$ 1234.56` — mesmo formato usado hoje
/// em todas as telas (ponto decimal, prefixo `R$ `).
String formatarMoeda(num valor) => 'R\$ ${valor.toStringAsFixed(2)}';

/// Número de exibição do pedido a partir da temporada: `26-1`, `27-3`, etc.
/// (ano em 2 dígitos + sequencial). Cai para `#id` quando o pedido não tem
/// temporada (dados antigos/importados sem número).
String formatarNumeroPedido(Map pedido) {
  final ano = pedido['temporada_ano'];
  final numero = pedido['numero_temporada'];
  if (ano != null && numero != null) {
    final aa = (ano % 100).toString().padLeft(2, '0');
    return '$aa-$numero';
  }
  return '#${pedido['id']}';
}

/// Formata um `DateTime` (ou ISO string) como `dd/MM/yyyy  HH:mm` no fuso local.
/// Retorna '—' quando o valor é nulo/inválido.
String formatarDataHora(dynamic valor) {
  if (valor == null) return '—';
  final dt = valor is DateTime
      ? valor
      : DateTime.tryParse(valor.toString())?.toLocal();
  if (dt == null) return '—';
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
