import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../auth/screens/login_screen.dart';
import '../../configuracoes/screens/configuracoes_screen.dart';
import '../../consulta/screens/consulta_hub_screen.dart';
import '../../pagamentos/screens/pagamentos_sem_conta_screen.dart';
import '../../relatorios/screens/relatorios_hub_screen.dart';
import 'widgets/card_pedido_entrega.dart';
import 'widgets/modal_entrega.dart';

class TelaEntregas extends StatefulWidget {
  const TelaEntregas({super.key});

  @override
  State<TelaEntregas> createState() => _TelaEntregasState();
}

class _TelaEntregasState extends State<TelaEntregas> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _carregando = false;
  Map<String, dynamic>? _clienteSelecionado;

  // Quantidade de pagamentos reais sem conta definida (sino do drawer)
  int _pendentesSemConta = 0;

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
    _carregarPendentesSemConta();
  }

  /// Conta os pagamentos sem conta definida para alimentar o sino do drawer.
  /// Falha silenciosa — o badge simplesmente não aparece se a chamada falhar.
  Future<void> _carregarPendentesSemConta() async {
    try {
      final response = await ApiService.dio.get('/pagamentos/pendentes-conta');
      final qtd = (response.data as List).length;
      if (mounted) setState(() => _pendentesSemConta = qtd);
    } catch (_) {
      // Ignora — não atrapalha o módulo
    }
  }

  /// Abre a tela de pagamentos sem conta (acionada pelo sino do drawer).
  Future<void> _abrirPagamentosSemConta() async {
    Navigator.pop(context); // fecha o drawer
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TelaPagamentosSemConta()),
    );
    // Ao voltar, atualiza o sino (uma conta pode ter sido definida)
    _carregarPendentesSemConta();
  }

  Future<void> _carregarPedidos() async {
    setState(() => _carregando = true);
    try {
      // Só pedidos com entrega pendente ou parcial; backend já limita a 20
      final params = <String, dynamic>{'statusEntrega': 'Pendente,Parcial'};
      if (_clienteSelecionado != null) {
        params['cliente'] = _clienteSelecionado!['nome'];
      }

      final response = await ApiService.dio.get(
        '/pedidos',
        queryParameters: params,
      );

      final lista = (response.data as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .take(20)
          .toList();

      setState(() {
        _pedidos = lista;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar pedidos. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    }
  }

  void _mostrarModalEntrega(Map<String, dynamic> pedido) {
    showDialog<void>(
      context: context,
      builder: (_) => ModalEntrega(
        pedido: pedido,
        onSalvo: () {
          Navigator.pop(context);
          _carregarPedidos();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entregas')),
      drawer: _buildDrawer(context),
      // Atualiza o sino de pagamentos sem conta sempre que o drawer abre
      onDrawerChanged: (aberto) {
        if (aberto) _carregarPendentesSemConta();
      },
      body: Column(
        children: [
          PesquisaClienteLista(
            clienteSelecionado: _clienteSelecionado,
            onSelecionado: (c) {
              setState(() => _clienteSelecionado = c);
              _carregarPedidos();
            },
            onLimpar: () {
              setState(() => _clienteSelecionado = null);
              _carregarPedidos();
            },
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _pedidos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum pedido com entrega pendente.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregarPedidos,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _pedidos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => CardPedidoEntrega(
                            pedido: _pedidos[i],
                            onRegistrarEntrega: () => _mostrarModalEntrega(_pedidos[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final nomeUsuario = AuthService.usuario?['nome'] as String? ?? 'Usuário';
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: cs.primary),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront, color: cs.onPrimary, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Sistema Promudas',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nomeUsuario,
                        style: TextStyle(
                          color: cs.onPrimary.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sino de notificações (canto superior direito do header).
                // FUTURO: centro de notificações geral, agregando todos os tipos
                // de alerta. Hoje a única fonte é "pagamentos sem conta".
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Pagamentos sem conta',
                    icon: Badge(
                      isLabelVisible: _pendentesSemConta > 0,
                      label: Text('$_pendentesSemConta'),
                      child: Icon(
                        _pendentesSemConta > 0
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: cs.onPrimary,
                      ),
                    ),
                    onPressed: _abrirPagamentosSemConta,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Trocar Módulo'),
            onTap: () {
              Navigator.pop(context); // fecha drawer
              Navigator.pop(context); // volta para TelaModulos
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Entregas'),
            selected: true,
            selectedColor: cs.primary,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Consulta'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaConsultaHub()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Relatórios'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaRelatoriosHub()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configuração'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaConfiguracoes()),
              );
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: CoresSemanticas.erro),
            title: const Text('Sair', style: TextStyle(color: CoresSemanticas.erro)),
            onTap: () {
              AuthService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const TelaLogin()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
