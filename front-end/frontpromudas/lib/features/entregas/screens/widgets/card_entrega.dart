import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';

/// Card de exibição de uma entrega já registrada.
/// Quando [onEditar]/[onExcluir] são informados, exibe o menu de ações.
class CardEntrega extends StatelessWidget {
  final Map<String, dynamic> entrega;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;

  const CardEntrega({
    super.key,
    required this.entrega,
    this.onEditar,
    this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pedido = entrega['pedidos'] as Map<String, dynamic>?;
    final numeroPedido = pedido != null ? formatarNumeroPedido(pedido) : '—';
    final cliente = capitalizarNome(
      (pedido?['clientes'] as Map<String, dynamic>?)?['nome'] as String? ??
          '—',
    );

    final data = formatarDataHora(entrega['data_entrega']);
    final local = entrega['local_entrega'] as String? ?? '—';
    final motorista = entrega['motorista'] as String?;
    final placa = entrega['placa_veiculo'] as String?;

    final itens = (entrega['itens_entrega'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: cliente + pedido + data
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pedido $numeroPedido · $data',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _PillLocal(local: local),
                if (onEditar != null || onExcluir != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: cs.onSurfaceVariant),
                    tooltip: 'Ações',
                    onSelected: (valor) {
                      if (valor == 'editar') onEditar?.call();
                      if (valor == 'excluir') onExcluir?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEditar != null)
                        const PopupMenuItem(
                          value: 'editar',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      if (onExcluir != null)
                        PopupMenuItem(
                          value: 'excluir',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline, color: cs.error),
                            title: Text('Excluir',
                                style: TextStyle(color: cs.error)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const Divider(height: 20),

            // Itens entregues
            ...itens.map((item) {
              final nomeProduto =
                  (item['produtos'] as Map?)?['nome'] as String? ?? '—';
              final qtd = item['quantidade'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(nomeProduto, style: const TextStyle(fontSize: 13))),
                    Text(
                      '${qtd}x',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),

            // Veículo (quando informado)
            if ((motorista != null && motorista.isNotEmpty) ||
                (placa != null && placa.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (motorista != null && motorista.isNotEmpty) motorista,
                        if (placa != null && placa.isNotEmpty) placa,
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillLocal extends StatelessWidget {
  final String local;
  const _PillLocal({required this.local});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        local,
        style: TextStyle(
          color: cor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
