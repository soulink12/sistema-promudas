// Formatadores puros reutilizados em todo o app (moeda e data/hora).

/// Formata um valor monetário como `R$ 1234.56` — mesmo formato usado hoje
/// em todas as telas (ponto decimal, prefixo `R$ `).
String formatarMoeda(num valor) => 'R\$ ${valor.toStringAsFixed(2)}';

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
