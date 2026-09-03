import 'package:flutter/material.dart';
import '../../../../core/widgets/chip_status.dart';
import '../../../../core/utils/formatadores.dart';
import '../../../../core/utils/status_orcamento.dart';

class ListaOrcamentos extends StatelessWidget {
  final List<Map<String, dynamic>> orcamentos;
  final void Function(Map<String, dynamic>) onSelecionarOrcamento;

  const ListaOrcamentos({
    super.key,
    required this.orcamentos,
    required this.onSelecionarOrcamento,
  });

  @override
  Widget build(BuildContext context) {
    if (orcamentos.isEmpty) {
      return Center(
        child: Text(
          'Nenhum orçamento encontrado.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orcamentos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final o = orcamentos[index];
        final cs = Theme.of(context).colorScheme;
        final nomeCliente = capitalizarNome(
          o['clientes']?['nome'] as String? ?? 'Cliente desconhecido',
        );
        final total = _toDouble(o['valor_total']);
        final data = formatarDataHora(o['data_orcamento'] ?? o['criado_em']);
        final status = o['status'] as String? ?? 'Pendente';

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelecionarOrcamento(o),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Orçamento ${formatarNumeroOrcamento(o)} · $data',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatarMoeda(total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ChipStatus(status: status, corOverride: corStatusOrcamento(status)),
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

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
