import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';

class CardPedidoEntrega extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback onRegistrarEntrega;

  const CardPedidoEntrega({
    super.key,
    required this.pedido,
    required this.onRegistrarEntrega,
  });

  String _formatarData(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final numero = formatarNumeroPedido(pedido);
    final clienteMap = pedido['clientes'] as Map<String, dynamic>?;
    final cliente = clienteMap?['nome'] as String? ?? '—';
    final statusRet = pedido['status_entrega'] as String? ?? '—';
    final data = _formatarData(pedido['criado_em'] as String?);
    final itens = pedido['itens_pedido'] as List?;
    final qtdItens = itens?.length ?? 0;

    final corStatus = statusRet == 'Parcial'
        ? CoresSemanticas.aviso
        : Theme.of(context).colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                    '$numero · $data · $qtdItens ${qtdItens == 1 ? 'item' : 'itens'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: corStatus.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: corStatus.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusRet,
                      style: TextStyle(
                        color: corStatus,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onRegistrarEntrega,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
