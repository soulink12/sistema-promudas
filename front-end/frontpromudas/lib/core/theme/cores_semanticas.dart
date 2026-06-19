import 'package:flutter/material.dart';

/// Acentos de cor com significado de negócio fixo, independentes do tema.
///
/// O app usa um [ColorScheme] semeado em verde (ver `main.dart`), então cores
/// decorativas devem vir de `Theme.of(context).colorScheme`. Já estes acentos
/// carregam significado próprio (desconto é azul, acréscimo é laranja, erro é
/// vermelho...) que não deve mudar com o tema — por isso ficam fixos, mas
/// centralizados aqui em vez de espalhados como `Colors.blue`/`orange`/`red`.
///
/// Os valores são os hex exatos das `Colors` que já eram usadas no código,
/// para que a centralização não altere nada visualmente.
abstract final class CoresSemanticas {
  // ----- Ajuste de preço / pedido -----

  /// Desconto, preço abaixo do sistema, valor "a menos". (`Colors.blue[700]`)
  static const Color desconto = Color(0xFF1976D2);

  /// Acréscimo, preço acima do sistema. (`Colors.orange[800]`)
  static const Color acrescimo = Color(0xFFEF6C00);

  // ----- Estados / status -----

  /// Sucesso: pago, entregue, realizada, nota emitida. (`Colors.green`)
  static const Color sucesso = Color(0xFF4CAF50);

  /// Informação: crédito, em processamento. (`Colors.blue`)
  static const Color info = Color(0xFF2196F3);

  /// Aviso: parcial, a receber, pendência (ex.: pagamento sem conta).
  /// (`Colors.orange`)
  static const Color aviso = Color(0xFFFF9800);

  /// Erro / ação destrutiva: rejeitada, excluir, sair. (`Colors.red`)
  static const Color erro = Color(0xFFF44336);

  /// Neutro: pendente, não informado. (`Colors.grey`)
  static const Color neutro = Color(0xFF9E9E9E);
}
