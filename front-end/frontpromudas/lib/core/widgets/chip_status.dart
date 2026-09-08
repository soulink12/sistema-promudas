import 'package:flutter/material.dart';
import '../theme/cores_semanticas.dart';

/// Chip de status colorido, reutilizado em listas, detalhes e relatórios.
/// A cor é derivada do [status]; [prefixo] precede o texto (ex.: 'Entrega: ')
/// e [count], quando informado, é exibido como sufixo (ex.: 'Pago: 5').
/// [corOverride] força uma cor específica em vez de inferir do texto — usado
/// pelo orçamento, cujo "Pendente" é laranja (diferente do "Pendente" neutro
/// de pagamento/entrega/nota do pedido, que usa o mesmo texto).
class ChipStatus extends StatelessWidget {
  final String status;
  final String prefixo;
  final int? count;
  final Color? corOverride;

  const ChipStatus({
    super.key,
    required this.status,
    this.prefixo = '',
    this.count,
    this.corOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (corOverride != null) {
      return _chip(corOverride!);
    }

    Color cor;
    switch (status.toLowerCase()) {
      case 'pago':
      case 'realizada':
      case 'entregue':
      case 'emitida':
      case 'aprovado':
        cor = CoresSemanticas.sucesso;
        break;
      case 'crédito':
      case 'processando':
        cor = CoresSemanticas.info;
        break;
      case 'parcial':
        cor = CoresSemanticas.aviso;
        break;
      case 'rejeitada':
      case 'rejeitado':
        cor = CoresSemanticas.erro;
        break;
      default:
        cor = CoresSemanticas.neutro; // Pendente / não informado
    }
    return _chip(cor);
  }

  Widget _chip(Color cor) {
    final label = '$prefixo$status${count != null ? ': $count' : ''}';
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: cor.withAlpha(30),
      side: BorderSide(color: cor.withAlpha(80)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
