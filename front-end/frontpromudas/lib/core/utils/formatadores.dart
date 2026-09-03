// Formatadores puros reutilizados em todo o app (moeda e data/hora).

/// Formata um valor monetário no padrão brasileiro: `R$ 1.234,56`
/// (ponto separando o milhar, vírgula separando os centavos, prefixo `R$ `).
String formatarMoeda(num valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final inteiro = partes[0];
  final centavos = partes[1];

  // Insere o ponto de milhar a cada 3 dígitos, da direita para a esquerda.
  final buffer = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buffer.write('.');
    buffer.write(inteiro[i]);
  }

  return 'R\$ ${negativo ? '-' : ''}$buffer,$centavos';
}

/// Formata uma quantidade (ex.: kg de escambo) de forma limpa, sem casas
/// decimais inúteis: `4` em vez de `4,00`; `3,5` em vez de `3,50`.
String formatarQuantidade(num valor) {
  var s = valor.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s.replaceAll('.', ',');
}

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

/// Número de exibição do orçamento: sempre `#id` — orçamento usa numeração
/// própria simples, sem o esquema de temporada do pedido.
String formatarNumeroOrcamento(Map orcamento) => '#${orcamento['id']}';

/// Padroniza a exibição de um nome próprio: primeira letra de cada palavra
/// maiúscula, resto minúsculo (ex.: "MARIA DA SILVA" ou "maria da silva" →
/// "Maria Da Silva"). Só afeta a exibição — o valor salvo no banco não muda.
String capitalizarNome(String nome) {
  return nome
      .trim()
      .split(RegExp(r'\s+'))
      .map((palavra) {
        if (palavra.isEmpty) return palavra;
        return palavra[0].toUpperCase() + palavra.substring(1).toLowerCase();
      })
      .join(' ');
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
