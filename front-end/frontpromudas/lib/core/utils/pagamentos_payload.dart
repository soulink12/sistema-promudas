/// Converte os pagamentos coletados no `ModalPagamento` (chaves em camelCase,
/// próprias do widget) para o formato aceito pela API (`snake_case`), capando
/// cada parcela pelo saldo restante — descarta troco em vez de mandar um
/// valor que o backend rejeitaria por exceder o total. Usado por todo lugar
/// que envia pagamento pra API: criação/edição de pedido e registro de
/// pagamento avulso (venda_screen.dart, pedidos_screen.dart) e aprovação de
/// orçamento (orcamentos_screen.dart).
List<Map<String, dynamic>> pagamentosParaPayload(
  List<Map<String, dynamic>> pagamentos,
  double saldoInicial,
) {
  double restante = saldoInicial;
  final corpo = <Map<String, dynamic>>[];
  for (final p in pagamentos) {
    if (restante <= 0.005) break;
    final valorPago = (p['valor'] as double).clamp(0.0, restante);
    corpo.add({
      'valor_pago': valorPago,
      'forma_pagamento': p['forma'],
      // Cheque (depósito posterior): data fica nula até o depósito.
      if (p['depositoPosterior'] != true)
        'data_pagamento': DateTime.now().toUtc().toIso8601String(),
      if (p['parcelas'] != null) 'parcelas': p['parcelas'],
      if (p['escamboQuantidade'] != null)
        'escambo_quantidade': p['escamboQuantidade'],
      if (p['conta'] != null) 'conta': p['conta'],
      if (p['nomePagador'] != null) 'nome_pagador': p['nomePagador'],
      if (p['cpfPagador'] != null) 'cpf_cnpj_pagador': p['cpfPagador'],
      if (p['cheques'] != null) 'cheques': p['cheques'],
    });
    restante -= valorPago;
  }
  return corpo;
}
