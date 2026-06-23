import 'package:flutter/material.dart';

/// Campos de detalhe de um cheque, exibidos inline no `ModalPagamento` quando a
/// forma é de depósito posterior. O valor do cheque NÃO entra aqui — é o mesmo
/// do campo "Valor" do pagamento. Ao clicar em "Adicionar", o modal monta um
/// cheque com estes campos e o valor digitado; repetir adiciona outro cheque.
///
/// Os controllers e a data são donos do `ModalPagamento` (este widget é só
/// layout), para o modal ler os valores ao adicionar a parcela.
class CamposCheque extends StatelessWidget {
  final TextEditingController numeroCtrl;
  final TextEditingController bancoCtrl;
  final TextEditingController agenciaCtrl;
  final TextEditingController contaCtrl;
  final DateTime? bomPara;
  final VoidCallback onEscolherData;
  final VoidCallback onLimparData;

  const CamposCheque({
    super.key,
    required this.numeroCtrl,
    required this.bancoCtrl,
    required this.agenciaCtrl,
    required this.contaCtrl,
    required this.bomPara,
    required this.onEscolherData,
    required this.onLimparData,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bomParaTexto = bomPara == null
        ? 'Bom para (opcional)'
        : 'Bom para: ${bomPara!.day.toString().padLeft(2, '0')}/'
            '${bomPara!.month.toString().padLeft(2, '0')}/${bomPara!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'DADOS DO CHEQUE (OPCIONAL)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'O valor do cheque é o do campo "Valor". Clique em "Adicionar" para '
          'cada cheque; podem ser completados depois, no depósito.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: numeroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nº do cheque',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: bancoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: agenciaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agência',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: contaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Conta corrente',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onEscolherData,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(bomParaTexto),
          ),
        ),
        if (bomPara != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onLimparData,
              child: Text('Limpar data',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }
}
