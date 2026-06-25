import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';

/// Campo do escambo (troca por produção), exibido inline no `ModalPagamento`
/// quando a forma é de escambo. O operador informa os kg de produção (ex.:
/// pimenta) recebidos; o valor em R$ é calculado pela taxa configurada na forma
/// (R$/kg) e preenchido no campo "Valor" do pagamento.
///
/// O controller e a taxa são donos do `ModalPagamento` (este widget é só
/// layout); `onKgChange` avisa o modal para recalcular o valor.
class CamposEscambo extends StatelessWidget {
  final TextEditingController kgCtrl;
  final double? valorKgEscambo;
  final ValueChanged<String> onKgChange;

  const CamposEscambo({
    super.key,
    required this.kgCtrl,
    required this.valorKgEscambo,
    required this.onKgChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kg = double.tryParse(kgCtrl.text.trim().replaceAll(',', '.'));
    final taxa = valorKgEscambo;

    String auxiliar;
    if (taxa == null || taxa <= 0) {
      auxiliar = 'Defina o valor por kg na forma de pagamento (Configurações).';
    } else if (kg == null || kg <= 0) {
      auxiliar = 'Taxa: ${formatarMoeda(taxa)}/kg';
    } else {
      auxiliar =
          'Taxa: ${formatarMoeda(taxa)}/kg → ${formatarMoeda(taxa * kg)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'ESCAMBO (PRODUÇÃO)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: kgCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onKgChange,
          decoration: InputDecoration(
            labelText: 'Kg de pimenta',
            helperText: auxiliar,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
