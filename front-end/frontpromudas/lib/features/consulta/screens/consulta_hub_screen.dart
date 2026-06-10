import 'package:flutter/material.dart';
import '../../clientes/screens/clientes_screen.dart';
import '../../pedidos/screens/pedidos_screen.dart';
import '../../retiradas/screens/consulta_retiradas_screen.dart';

class TelaConsultaHub extends StatelessWidget {
  const TelaConsultaHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CardConsulta(
            icon: Icons.people_outline,
            titulo: 'Clientes',
            descricao:
                'Busque clientes, veja dados de contato, crédito e pedidos pendentes.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaListaClientes()),
            ),
          ),
          const SizedBox(height: 12),
          _CardConsulta(
            icon: Icons.receipt_long_outlined,
            titulo: 'Pedidos',
            descricao:
                'Consulte pedidos, registre pagamentos, emita PDF e edite itens.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaPedidos()),
            ),
          ),
          const SizedBox(height: 12),
          _CardConsulta(
            icon: Icons.inventory_2_outlined,
            titulo: 'Retiradas',
            descricao:
                'Consulte as retiradas já registradas, com itens, local de saída e veículo.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaConsultaRetiradas()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardConsulta extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _CardConsulta({
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
