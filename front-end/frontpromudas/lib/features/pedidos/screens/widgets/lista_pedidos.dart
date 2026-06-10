import 'package:flutter/material.dart';

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
      return const Center(
        child: Text(
          'Nenhum pedido encontrado.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: pedidos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = pedidos[index];
        final nomeCliente =
            p['clientes']?['nome'] as String? ?? 'Cliente desconhecido';
        final total = _toDouble(p['valor_total']);
        final data = _formatarDataHora(p['criado_em']);
        final statusPag = p['status_pagamento'] as String? ?? 'Pendente';

        return ListTile(
          leading: _BadgeId(id: p['id'] as int),
          title: Text(nomeCliente,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${data ?? '—'}  •  R\$ ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: ChipStatus(status: statusPag),
          onTap: () => onSelecionarPedido(p),
        );
      },
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _BadgeId extends StatelessWidget {
  final int id;
  const _BadgeId({required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Center(
        child: Text(
          '#$id',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.green[800]),
        ),
      ),
    );
  }
}

class ChipStatus extends StatelessWidget {
  final String status;
  final String prefixo;

  const ChipStatus({super.key, required this.status, this.prefixo = ''});

  @override
  Widget build(BuildContext context) {
    Color cor;
    switch (status.toLowerCase()) {
      case 'pago':
      case 'realizada':
        cor = Colors.green;
        break;
      case 'crédito':
        cor = Colors.blue;
        break;
      case 'parcial':
        cor = Colors.orange;
        break;
      default:
        cor = Colors.grey;
    }
    return Chip(
      label: Text('$prefixo$status', style: const TextStyle(fontSize: 11)),
      backgroundColor: cor.withAlpha(30),
      side: BorderSide(color: cor.withAlpha(80)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
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
