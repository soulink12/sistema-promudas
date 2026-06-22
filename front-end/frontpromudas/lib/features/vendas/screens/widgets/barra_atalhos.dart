import 'package:flutter/material.dart';

/// Barra fixa no rodapé do PDV com os atalhos de teclado do programa.
/// Puramente informativa (sem interação) — está sempre visível, listando
/// todos os atalhos disponíveis.
class BarraAtalhos extends StatelessWidget {
  const BarraAtalhos({super.key});

  // Atalhos disponíveis no PDV (tecla, descrição).
  static const List<(String, String)> _atalhos = [
    ('F5', 'Buscar cliente'),
    ('F12', 'Finalizar pagamento'),
    ('Ctrl+C', 'Cadastrar cliente'),
    ('Ctrl+E', 'Pesquisar pedido'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (tecla, descricao) in _atalhos)
            _item(cs, tecla, descricao),
        ],
      ),
    );
  }

  /// Um par tecla + descrição: a tecla num "badge" e a descrição ao lado.
  Widget _item(ColorScheme cs, String tecla, String descricao) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            tecla,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          descricao,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
