import 'package:flutter/material.dart';
import '../../../../core/widgets/chip_status.dart';
import '../../../../core/utils/formatadores.dart';

class ListaPedidos extends StatelessWidget {
  final List<Map<String, dynamic>> pedidos;
  final void Function(Map<String, dynamic>) onSelecionarPedido;

  const ListaPedidos({
    super.key,
    required this.pedidos,
    required this.onSelecionarPedido,
  });

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) {
      return Center(
        child: Text(
          'Nenhum pedido encontrado.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pedidos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = pedidos[index];
        final cs = Theme.of(context).colorScheme;
        final nomeCliente = capitalizarNome(
          p['clientes']?['nome'] as String? ?? 'Cliente desconhecido',
        );
        final total = _toDouble(p['valor_total']);
        final data = formatarDataHora(p['data_pedido'] ?? p['criado_em']);
        final statusPag = p['status_pagamento'] as String? ?? 'Pendente';
        final statusEntrega = p['status_entrega'] as String? ?? 'Pendente';
        final statusNota = _statusNotaPedido(p['pagamentos'] as List? ?? []);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelecionarPedido(p),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeCliente,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pedido ${formatarNumeroPedido(p)} · $data',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatarMoeda(total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChipStatus(status: statusPag),
                      ChipStatus(status: statusEntrega, prefixo: 'Entrega: '),
                      ChipStatus(status: statusNota, prefixo: 'Nota: '),
                    ],
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

// ── Funções utilitárias ───────────────────────────────────────────────────────

/// Status da nota fiscal do pedido, agregado a partir dos pagamentos reais
/// (crediário/"a receber" não conta — ainda não há nota). Prioridade:
/// Rejeitada > Processando > Emitida (todas) > Parcial (algumas) > Pendente.
/// O backend replica esta mesma regra para o filtro de status de nota (pedidoService.js).
String _statusNotaPedido(List pagamentos) {
  final reais = pagamentos
      .where((p) => (p as Map)['pagamento_posterior'] != true)
      .toList();
  if (reais.isEmpty) return 'Pendente';

  final statuses = reais
      .map((p) => (p as Map)['status_nota'] as String? ?? 'Pendente')
      .toList();

  if (statuses.contains('Rejeitada')) return 'Rejeitada';
  if (statuses.contains('Processando')) return 'Processando';

  final emitidas = statuses.where((s) => s == 'Emitida').length;
  if (emitidas == 0) return 'Pendente';
  if (emitidas == statuses.length) return 'Emitida';
  return 'Parcial';
}

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
