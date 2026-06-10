import 'package:flutter/material.dart';

/// Card de exibição de uma entrega já registrada.
/// Quando [onEditar]/[onExcluir] são informados, exibe o menu de ações.
class CardRetirada extends StatelessWidget {
  final Map<String, dynamic> retirada;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;

  const CardRetirada({
    super.key,
    required this.retirada,
    this.onEditar,
    this.onExcluir,
  });

  String _formatarData(dynamic iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pedido = retirada['pedidos'] as Map<String, dynamic>?;
    final pedidoId = pedido?['id'];
    final cliente =
        (pedido?['clientes'] as Map<String, dynamic>?)?['nome'] as String? ??
            '—';

    final data = _formatarData(retirada['data_retirada']);
    final local = retirada['local_saida'] as String? ?? '—';
    final motorista = retirada['motorista'] as String?;
    final placa = retirada['placa_veiculo'] as String?;

    final itens = (retirada['itens_retirada'] as List? ?? [])
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
                        'Pedido #$pedidoId · $data',
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

            // Itens retirados
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
