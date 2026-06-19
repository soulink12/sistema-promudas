import 'package:flutter/material.dart';

/// Uma linha da tabela de itens nos detalhes do pedido. Quando [isHeader] é
/// true, aplica o estilo de cabeçalho (fundo destacado, texto em negrito).
/// [cells] e [flex] devem ter o mesmo comprimento; a primeira coluna alinha à
/// esquerda e as demais à direita.
class LinhaTabela extends StatelessWidget {
  final List<String> cells;
  final List<int> flex;
  final bool isHeader;

  const LinhaTabela({
    super.key,
    required this.cells,
    required this.flex,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: isHeader ? cs.surfaceContainerHighest : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(cells.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(
              cells[i],
              textAlign: i > 0 ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 13 : 14,
                color: isHeader ? cs.onSurfaceVariant : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
