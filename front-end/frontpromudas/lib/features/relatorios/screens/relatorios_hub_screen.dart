import 'package:flutter/material.dart';
import 'relatorios_pagamentos_screen.dart';
import 'relatorio_pedidos_screen.dart';

class TelaRelatoriosHub extends StatelessWidget {
  const TelaRelatoriosHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CardRelatorio(
            icon: Icons.payments_outlined,
            titulo: 'Pagamentos',
            descricao:
                'Total recebido por forma de pagamento, com filtro por data e forma.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaRelatorioPagamentos()),
            ),
          ),
          const SizedBox(height: 12),
          _CardRelatorio(
            icon: Icons.receipt_long_outlined,
            titulo: 'Pedidos',
            descricao:
                'Lista de pedidos com filtro por data, status de pagamento, status de retirada e cliente.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaRelatorioPedidos()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRelatorio extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _CardRelatorio({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: Colors.green[50],
          child: Icon(icon, color: Colors.green[700]),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            descricao,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
