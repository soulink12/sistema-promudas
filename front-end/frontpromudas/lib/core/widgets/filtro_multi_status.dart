import 'package:flutter/material.dart';

/// Botão-dropdown de filtro com **seleção múltipla** (checkboxes). Mostra um
/// rótulo e, quando há marcações, a contagem entre parênteses. O menu permanece
/// aberto para marcar/desmarcar vários itens de uma vez.
///
/// Sem nada marcado = sem filtro (responsabilidade de quem consome o callback).
/// Reutilizável em qualquer tela de listagem (ex.: filtros de status em pedidos).
class FiltroMultiStatus extends StatelessWidget {
  final String rotulo;
  final List<String> opcoes;
  final Set<String> selecionados;
  final ValueChanged<Set<String>> onChanged;

  const FiltroMultiStatus({
    super.key,
    required this.rotulo,
    required this.opcoes,
    required this.selecionados,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ativo = selecionados.isNotEmpty;

    return MenuAnchor(
      menuChildren: [
        for (final opcao in opcoes)
          CheckboxMenuButton(
            value: selecionados.contains(opcao),
            closeOnActivate: false,
            onChanged: (marcado) {
              final novo = Set<String>.from(selecionados);
              if (marcado == true) {
                novo.add(opcao);
              } else {
                novo.remove(opcao);
              }
              onChanged(novo);
            },
            child: Text(opcao),
          ),
      ],
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          // Seta de dropdown à esquerda do rótulo.
          icon: const Icon(Icons.arrow_drop_down, size: 22),
          label: Text(ativo ? '$rotulo (${selecionados.length})' : rotulo),
          style: OutlinedButton.styleFrom(
            foregroundColor: ativo ? cs.primary : cs.onSurfaceVariant,
            side: BorderSide(color: ativo ? cs.primary : cs.outlineVariant),
          ),
        );
      },
    );
  }
}
