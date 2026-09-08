import 'package:flutter/material.dart';
import '../theme/cores_semanticas.dart';

/// Cor do status do orçamento (Pendente/Aprovado/Rejeitado) — usada com
/// [ChipStatus.corOverride], já que o "Pendente" do orçamento é laranja,
/// diferente do "Pendente" neutro usado em pagamento/entrega/nota do pedido.
Color corStatusOrcamento(String? status) {
  switch (status) {
    case 'Aprovado':
      return CoresSemanticas.sucesso;
    case 'Rejeitado':
      return CoresSemanticas.erro;
    default:
      return CoresSemanticas.aviso; // Pendente
  }
}
