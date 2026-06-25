import 'package:flutter/material.dart';
import 'produtos_screen.dart';
import 'formas_pagamento_screen.dart';
import 'temporadas_screen.dart';

/// Configurações do Sistema — cadastros que afetam o funcionamento do sistema:
/// produtos (catálogo) e formas de pagamento. Exclusiva da Administração.
/// As preferências de aparência (tema/fonte) ficam em [TelaConfiguracoes],
/// transversal a todos os módulos.
class TelaConfiguracoesSistema extends StatelessWidget {
  const TelaConfiguracoesSistema({super.key});

  void _abrir(BuildContext context, Widget tela) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações do Sistema')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.eco_outlined, color: cs.primary),
            title: const Text('Produtos'),
            subtitle: const Text('Adicionar, editar ou desativar produtos.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(context, const TelaProdutos()),
          ),
          ListTile(
            leading: Icon(Icons.payment_outlined, color: cs.primary),
            title: const Text('Formas de Pagamento'),
            subtitle:
                const Text('Adicionar, editar ou remover formas de pagamento.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(context, const TelaFormasPagamento()),
          ),
          ListTile(
            leading: Icon(Icons.calendar_today_outlined, color: cs.primary),
            title: const Text('Temporadas'),
            subtitle: const Text(
                'Definir a temporada ativa — numera os pedidos (ex.: 26-1).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(context, const TelaTemporadas()),
          ),
        ],
      ),
    );
  }
}
