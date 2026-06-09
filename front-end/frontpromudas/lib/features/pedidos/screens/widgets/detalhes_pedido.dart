import 'package:flutter/material.dart';
import 'lista_pedidos.dart' show ChipStatus;

class DetalhesPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final bool salvando;
  final VoidCallback onVoltar;
  final VoidCallback onRegistrarPagamento;

  const DetalhesPedido({
    super.key,
    required this.pedido,
    required this.salvando,
    required this.onVoltar,
    required this.onRegistrarPagamento,
  });

  @override
  Widget build(BuildContext context) {
    final nomeCliente = pedido['clientes']?['nome'] as String? ?? '—';
    final total = _toDouble(pedido['valor_total']);
    final ajuste = _toDouble(pedido['ajuste']);
    final data = _formatarDataHora(pedido['criado_em']);
    final statusPag = pedido['status_pagamento'] as String? ?? 'Pendente';
    final statusRet = pedido['status_retirada'] as String? ?? 'Pendente';
    final obs = pedido['observacoes'] as String?;

    final itens = (pedido['itens_pedido'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final todosPagamentos = (pedido['pagamentos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final pagamentosReais =
        todosPagamentos.where((p) => p['pagamento_posterior'] != true).toList();
    final saldoCredito = todosPagamentos
        .where((p) => p['pagamento_posterior'] == true)
        .fold<double>(0.0, (s, p) => s + _toDouble(p['valor_pago']));

    final podePagar = statusPag == 'Pendente' || statusPag == 'Parcial';

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
              Text(
                'Pedido #${pedido['id']}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nomeCliente,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(data ?? '—',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${total.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          if (ajuste != 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${ajuste < 0 ? 'Desconto' : 'Acréscimo'}: R\$ ${ajuste.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: ajuste < 0
                                      ? Colors.blue[700]
                                      : Colors.orange[800]),
                            ),
                          ],
                          if (saldoCredito > 0.005) ...[
                            const SizedBox(height: 4),
                            Text(
                              'A receber: R\$ ${saldoCredito.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800]),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChipStatus(status: statusPag),
                      ChipStatus(status: statusRet, prefixo: 'Retirada: '),
                    ],
                  ),
                  if (obs != null && obs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Observações:',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(obs),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Itens do pedido
          _TituloSecao(titulo: 'Itens do Pedido'),
          Card(
            child: itens.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum item registrado.'),
                  )
                : Column(
                    children: [
                      _LinhaTabela(
                        isHeader: true,
                        cells: const ['Produto', 'Qtd.', 'Preço Unit.', 'Total'],
                        flex: const [4, 1, 2, 2],
                      ),
                      const Divider(height: 1),
                      ...itens.map((item) {
                        final nomeProduto =
                            item['produtos']?['nome'] as String? ?? '—';
                        final qtd = item['quantidade'] as int? ?? 0;
                        final preco = _toDouble(item['valor_unitario']);
                        final totalItem = preco * qtd;
                        return Column(
                          children: [
                            _LinhaTabela(
                              cells: [
                                nomeProduto,
                                '$qtd',
                                'R\$ ${preco.toStringAsFixed(2)}',
                                'R\$ ${totalItem.toStringAsFixed(2)}',
                              ],
                              flex: const [4, 1, 2, 2],
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Pagamentos recebidos
          _TituloSecao(titulo: 'Pagamentos'),
          Card(
            child: pagamentosReais.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum pagamento recebido ainda.'),
                  )
                : Column(
                    children: pagamentosReais.map((pag) {
                      final dataPag =
                          _formatarDataHora(pag['criado_em']) ?? '—';
                      final forma = pag['forma_pagamento'] as String? ?? '—';
                      final valor = _toDouble(pag['valor_pago']);
                      return ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(forma),
                        subtitle: Text(dataPag),
                        trailing: Text(
                          'R\$ ${valor.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // Botão de registrar pagamento
          if (podePagar) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: salvando ? null : onRegistrarPagamento,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Registrar Pagamento'),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _TituloSecao extends StatelessWidget {
  final String titulo;
  const _TituloSecao({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.green[700],
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LinhaTabela extends StatelessWidget {
  final List<String> cells;
  final List<int> flex;
  final bool isHeader;

  const _LinhaTabela({
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

// ── Funções utilitárias ───────────────────────────────────────────────────────

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

String? _formatarDataHora(dynamic valor) {
  if (valor == null) return null;
  try {
    final dt = DateTime.parse(valor.toString()).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return valor.toString();
  }
}
