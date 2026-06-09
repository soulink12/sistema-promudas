import 'package:flutter/material.dart';
import '../../../../features/pedidos/screens/widgets/lista_pedidos.dart'
    show ChipStatus;

class DetalhesCliente extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final List<Map<String, dynamic>> pedidosCliente;
  final bool carregandoPedidos;
  final VoidCallback onIniciarEdicao;
  final void Function(Map<String, dynamic> pedido) onTapPedido;
  final VoidCallback onVerTodosPedidos;

  const DetalhesCliente({
    super.key,
    required this.cliente,
    required this.pedidosCliente,
    required this.carregandoPedidos,
    required this.onIniciarEdicao,
    required this.onTapPedido,
    required this.onVerTodosPedidos,
  });

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    final nome = c['nome'] as String? ?? '';
    final pendentes = pedidosCliente
        .where((p) {
          final s = p['status_pagamento'] as String? ?? '';
          return s == 'Pendente' || s == 'Parcial';
        })
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card do cliente ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.green[100],
                        child: Text(
                          _iniciais(nome),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nome,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            Text('ID: ${c['id']}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar cliente',
                        onPressed: onIniciarEdicao,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  ...[
                    _secao('Identificação', [
                      ('CPF / CNPJ', c['cpf_cnpj']),
                      ('Inscrição Estadual', c['inscricao_estadual']),
                    ]),
                    _secao('Contato', [
                      ('Telefone', c['telefone_1']),
                      ('Telefone 2', c['telefone_2']),
                    ]),
                    _secao('Endereço', [
                      ('CEP', c['cep']),
                      ('Logradouro', c['logradouro']),
                      ('Número', c['numero']),
                      ('Bairro', c['bairro']),
                      ('Cidade', c['cidade']),
                      ('Estado', c['estado']),
                    ]),
                    _secao('Sistema', [
                      ('Cadastrado em', _formatarData(c['criado_em'])),
                    ]),
                  ].whereType<Widget>(),
                ],
              ),
            ),
          ),

          // ── Pedidos pendentes ──────────────────────────────────────────
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'PEDIDOS PENDENTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
              if (!carregandoPedidos && pendentes.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    '${pendentes.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (carregandoPedidos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pendentes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum pedido com pagamento pendente.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            )
          else
            Card(
              child: Column(
                children: pendentes.map((p) {
                  final id = p['id'] as int;
                  final total = _toDouble(p['valor_total']);
                  final status =
                      p['status_pagamento'] as String? ?? 'Pendente';
                  final data = _formatarData(p['criado_em']) ?? '—';
                  final pagamentos = (p['pagamentos'] as List? ?? []);
                  final totalPagoReal =
                      pagamentos.fold<double>(0.0, (soma, pag) {
                    final isPosterior =
                        (pag as Map)['pagamento_posterior'] == true;
                    return isPosterior
                        ? soma
                        : soma + _toDouble(pag['valor_pago']);
                  });
                  final valorPendente =
                      (total - totalPagoReal).clamp(0.0, total);

                  return Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.green.shade200),
                          ),
                          child: Center(
                            child: Text(
                              '#$id',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Valor pendente do pedido #$id é R\$ ${valorPendente.toStringAsFixed(2)}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(data,
                            style: const TextStyle(fontSize: 12)),
                        trailing: ChipStatus(status: status),
                        onTap: () => onTapPedido(p),
                      ),
                      if (p != pendentes.last) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onVerTodosPedidos,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver todos os pedidos'),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

Widget? _secao(String titulo, List<(String, dynamic)> campos) {
  final preenchidos =
      campos.where((f) => f.$2 != null && f.$2.toString().isNotEmpty).toList();
  if (preenchidos.isEmpty) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 0.8),
      ),
      const SizedBox(height: 10),
      ...preenchidos.map((f) => _linha(f.$1, f.$2)),
      const SizedBox(height: 20),
    ],
  );
}

Widget _linha(String label, dynamic valor) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ),
        Expanded(
          child: Text(valor.toString(), style: const TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

// ── Funções utilitárias ─────────────────────────────────────────────────────

String _iniciais(String nome) {
  final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

String? _formatarData(dynamic valor) {
  if (valor == null) return null;
  try {
    final dt = DateTime.parse(valor.toString()).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  } catch (_) {
    return valor.toString();
  }
}
