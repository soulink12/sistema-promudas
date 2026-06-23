import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../configuracoes/screens/configuracoes_screen.dart';
import '../../configuracoes/screens/produtos_screen.dart';
import '../../configuracoes/screens/formas_pagamento_screen.dart';
import '../../relatorios/screens/relatorios_hub_screen.dart';
import '../../notificacoes/screens/notificacoes_screen.dart';
import '../../clientes/screens/clientes_screen.dart';
import '../../pedidos/screens/pedidos_screen.dart';

/// Módulo de Administração — agrupa as funções que não são do operador de caixa:
/// relatórios, cadastros (produtos/formas), conciliação de pagamentos sem conta e
/// aparência. Acessado a partir de [TelaModulos]. É a base da separação por módulo;
/// no futuro o acesso a este módulo será gateado por permissão de usuário.
class TelaAdmin extends StatefulWidget {
  const TelaAdmin({super.key});

  @override
  State<TelaAdmin> createState() => _TelaAdminState();
}

class _TelaAdminState extends State<TelaAdmin> {
  // Total de pendências (cheques a depositar + pagamentos sem conta) exibido como
  // badge do card de Notificações — o sino geral do sistema, agora na Administração.
  int _totalNotificacoes = 0;

  @override
  void initState() {
    super.initState();
    _carregarNotificacoes();
  }

  /// Soma as pendências de todos os tipos. Falha silenciosa por tipo — o badge
  /// apenas não conta aquele tipo se o endpoint falhar.
  Future<void> _carregarNotificacoes() async {
    int total = 0;
    try {
      final r = await ApiService.dio.get('/cheques/a-depositar');
      total += (r.data as List).length;
    } catch (_) {}
    try {
      final r = await ApiService.dio.get('/pagamentos/pendentes-conta');
      total += (r.data as List).length;
    } catch (_) {}
    if (mounted) setState(() => _totalNotificacoes = total);
  }

  /// Abre uma sub-tela e, ao voltar, recarrega a contagem (pode ter mudado).
  Future<void> _abrir(Widget tela) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => tela),
    );
    _carregarNotificacoes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CardAdmin(
            icon: Icons.people_outline,
            titulo: 'Clientes',
            descricao: 'Consultar, cadastrar e editar clientes.',
            onTap: () => _abrir(const TelaListaClientes()),
          ),
          const SizedBox(height: 12),
          _CardAdmin(
            icon: Icons.receipt_long_outlined,
            titulo: 'Pedidos',
            descricao:
                'Consultar pedidos e seus pagamentos; registrar pagamento e emitir PDF.',
            onTap: () => _abrir(const TelaPedidos()),
          ),
          const SizedBox(height: 12),
          _CardAdmin(
            icon: Icons.bar_chart_outlined,
            titulo: 'Relatórios',
            descricao:
                'Relatórios de pagamentos e de pedidos, com filtros e exportação em PDF.',
            onTap: () => _abrir(const TelaRelatoriosHub()),
          ),
          const SizedBox(height: 12),
          _CardAdmin(
            icon: Icons.eco_outlined,
            titulo: 'Produtos',
            descricao: 'Adicionar, editar ou desativar produtos do catálogo.',
            onTap: () => _abrir(const TelaProdutos()),
          ),
          const SizedBox(height: 12),
          _CardAdmin(
            icon: Icons.payment_outlined,
            titulo: 'Formas de Pagamento',
            descricao: 'Adicionar, editar ou remover formas de pagamento.',
            onTap: () => _abrir(const TelaFormasPagamento()),
          ),
          const SizedBox(height: 12),
          _CardAdmin(
            icon: Icons.notifications_outlined,
            titulo: 'Notificações',
            descricao:
                'Pendências do sistema: cheques a depositar e pagamentos sem conta.',
            badge: _totalNotificacoes,
            onTap: () => _abrir(const TelaNotificacoes()),
          ),
          const SizedBox(height: 12),
          _CardAdmin(
            icon: Icons.settings_outlined,
            titulo: 'Configuração',
            descricao: 'Tema claro/escuro e tamanho da fonte do sistema.',
            onTap: () => _abrir(const TelaConfiguracoes()),
          ),
        ],
      ),
    );
  }
}

class _CardAdmin extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;
  // Contagem opcional exibida como Badge sobre o ícone (0 = oculto).
  final int badge;

  const _CardAdmin({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            descricao,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
