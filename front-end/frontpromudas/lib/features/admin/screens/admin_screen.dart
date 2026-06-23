import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../configuracoes/screens/configuracoes_screen.dart';
import '../../configuracoes/screens/produtos_screen.dart';
import '../../configuracoes/screens/formas_pagamento_screen.dart';
import '../../relatorios/screens/relatorios_hub_screen.dart';
import '../../pagamentos/screens/pagamentos_sem_conta_screen.dart';

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
  // Quantidade de pagamentos reais sem conta definida (badge do card).
  // Herda o papel do antigo sino do drawer, agora dentro da Administração.
  int _pendentesSemConta = 0;

  @override
  void initState() {
    super.initState();
    _carregarPendentesSemConta();
  }

  /// Conta os pagamentos sem conta. Falha silenciosa — o badge só não aparece.
  Future<void> _carregarPendentesSemConta() async {
    try {
      final response = await ApiService.dio.get('/pagamentos/pendentes-conta');
      final qtd = (response.data as List).length;
      if (mounted) setState(() => _pendentesSemConta = qtd);
    } catch (_) {
      // Ignora — não atrapalha o módulo
    }
  }

  /// Abre uma sub-tela e, ao voltar, recarrega a contagem (pode ter mudado).
  Future<void> _abrir(Widget tela) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => tela),
    );
    _carregarPendentesSemConta();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administração')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            icon: Icons.account_balance_outlined,
            titulo: 'Pagamentos sem conta',
            descricao:
                'Pagamentos sem conta definida (ex: dinheiro, cheque). Defina a conta de cada um.',
            badge: _pendentesSemConta,
            onTap: () => _abrir(const TelaPagamentosSemConta()),
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
