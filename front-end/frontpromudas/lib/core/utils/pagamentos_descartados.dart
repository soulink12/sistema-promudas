/// Retorna true se, ao aplicar [pagamentos] contra [saldoInicial] capando
/// cada parcela pelo saldo restante (mesma lógica usada ao enviar os
/// pagamentos pra API), alguma parcela é reduzida ou descartada — ou seja,
/// o valor de troco não foi registrado como pagamento.
bool haPagamentosDescartados(
  List<Map<String, dynamic>> pagamentos,
  double saldoInicial,
) {
  double restante = saldoInicial;
  for (final p in pagamentos) {
    if (restante <= 0.005) return true;
    final valor = p['valor'] as double;
    if (valor > restante + 0.005) return true;
    restante -= valor;
  }
  return false;
}
