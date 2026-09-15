import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';
import '../../../pedidos/screens/widgets/titulo_secao.dart';
import '../../../pedidos/screens/widgets/linha_tabela.dart';

class DetalhesInteressado extends StatelessWidget {
  final Map<String, dynamic> interessado;
  final bool salvando;
  final VoidCallback onVoltar;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onTapCliente;

  const DetalhesInteressado({
    super.key,
    required this.interessado,
    required this.salvando,
    required this.onVoltar,
    required this.onEditar,
    required this.onExcluir,
    required this.onTapCliente,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeCliente = capitalizarNome(interessado['clientes']?['nome'] as String? ?? '—');
    final data = formatarDataHora(interessado['criado_em']);
    final obs = interessado['observacoes'] as String?;

    final itens = (interessado['itens_interesse'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar para a lista',
                onPressed: onVoltar,
              ),
              const SizedBox(width: 4),
              const Text(
                'Interessado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Opções',
                onSelected: (valor) {
                  switch (valor) {
                    case 'editar':
                      onEditar();
                      break;
                    case 'excluir':
                      onExcluir();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar interessado'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: cs.error),
                      title: Text('Excluir interessado', style: TextStyle(color: cs.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Card de informações gerais
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onTapCliente,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              nomeCliente,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 20, color: cs.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(data, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  if (obs != null && obs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Observações:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(obs),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mudas de interesse
          const TituloSecao(titulo: 'Mudas de Interesse'),
          Card(
            child: itens.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma muda registrada.'),
                  )
                : Column(
                    children: [
                      const LinhaTabela(
                        isHeader: true,
                        cells: ['Muda', 'Qtd.'],
                        flex: [4, 1],
                      ),
                      const Divider(height: 1),
                      ...itens.map((item) {
                        final nomeProduto = item['produtos']?['nome'] as String? ?? '—';
                        final qtd = item['quantidade'] as int? ?? 0;
                        return Column(
                          children: [
                            LinhaTabela(
                              cells: [nomeProduto, '$qtd'],
                              flex: const [4, 1],
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
