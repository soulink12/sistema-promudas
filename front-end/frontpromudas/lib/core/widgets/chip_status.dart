import 'package:flutter/material.dart';
import '../theme/cores_semanticas.dart';

/// Chip de status colorido, reutilizado em listas, detalhes e relatórios.
/// A cor é derivada do [status]; [prefixo] precede o texto (ex.: 'Entrega: ')
/// e [count], quando informado, é exibido como sufixo (ex.: 'Pago: 5').
class ChipStatus extends StatelessWidget {
  final String status;
  final String prefixo;
  final int? count;

  const ChipStatus({
    super.key,
    required this.status,
    this.prefixo = '',
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    Color cor;
    switch (status.toLowerCase()) {
      case 'pago':
      case 'realizada':
      case 'entregue':
      case 'emitida':
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
        cor = CoresSemanticas.erro;
        break;
      default:
        cor = CoresSemanticas.neutro; // Pendente / não informado
    }
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
