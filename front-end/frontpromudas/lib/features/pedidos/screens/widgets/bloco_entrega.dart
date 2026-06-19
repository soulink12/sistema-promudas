import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';

/// Bloco de uma entrega na lista de detalhes do pedido — mostra o local de
/// saída, a data/hora, os itens entregues e, quando houver, o veículo.
/// [nomesPorProduto] mapeia `produto_id` → nome (os itens da entrega não
/// trazem o nome do produto).
class BlocoEntrega extends StatelessWidget {
  final Map<String, dynamic> entrega;
  final Map<int, String> nomesPorProduto;

  const BlocoEntrega({
    super.key,
    required this.entrega,
    required this.nomesPorProduto,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = formatarDataHora(entrega['data_entrega']);
    final local = entrega['local_entrega'] as String? ?? '—';
    final motorista = entrega['motorista'] as String?;
    final placa = entrega['placa_veiculo'] as String?;

    final itens = (entrega['itens_entrega'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final temVeiculo = (motorista != null && motorista.isNotEmpty) ||
        (placa != null && placa.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: local de saída + data
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                local,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                data,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Itens entregues
          ...itens.map((item) {
            final prodId = item['produto_id'] as int?;
            final nome = prodId != null ? nomesPorProduto[prodId] : null;
            final qtd = item['quantidade'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(nome ?? '—', style: const TextStyle(fontSize: 13)),
                  ),
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
          if (temVeiculo) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
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
            ),
          ],
        ],
      ),
    );
  }
}
