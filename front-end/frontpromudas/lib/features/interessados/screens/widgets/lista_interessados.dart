import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';

class ListaInteressados extends StatelessWidget {
  final List<Map<String, dynamic>> interessados;
  final void Function(Map<String, dynamic>) onSelecionarInteressado;

  const ListaInteressados({
    super.key,
    required this.interessados,
    required this.onSelecionarInteressado,
  });

  @override
  Widget build(BuildContext context) {
    if (interessados.isEmpty) {
      return Center(
        child: Text(
          'Nenhum interessado cadastrado.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: interessados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final interessado = interessados[index];
        final cs = Theme.of(context).colorScheme;
        final nomeCliente = capitalizarNome(
          interessado['clientes']?['nome'] as String? ?? 'Cliente desconhecido',
        );
        final itens = (interessado['itens_interesse'] as List? ?? []);
        final qtdMudas = itens.fold<int>(0, (soma, item) => soma + (item['quantidade'] as int? ?? 0));
        final resumoProdutos = itens
            .map((item) => (item['produtos'] as Map?)?['nome'] as String? ?? '—')
            .join(', ');
        final data = formatarDataHora(interessado['criado_em']);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelecionarInteressado(interessado),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeCliente,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resumoProdutos.isEmpty ? 'Sem mudas registradas' : resumoProdutos,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$qtdMudas ${qtdMudas == 1 ? 'muda' : 'mudas'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
