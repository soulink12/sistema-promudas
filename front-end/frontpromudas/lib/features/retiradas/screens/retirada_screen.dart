import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../auth/screens/login_screen.dart';
import '../../clientes/screens/clientes_screen.dart';
import '../../configuracoes/screens/configuracoes_screen.dart';
import '../../pedidos/screens/pedidos_screen.dart';
import '../../relatorios/screens/relatorios_hub_screen.dart';
import 'widgets/card_pedido_retirada.dart';
import 'widgets/modal_retirada.dart';

class TelaRetiradas extends StatefulWidget {
  const TelaRetiradas({super.key});

  @override
  State<TelaRetiradas> createState() => _TelaRetiradasState();
}

class _TelaRetiradasState extends State<TelaRetiradas> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _carregando = false;
  Map<String, dynamic>? _clienteSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
  }

  Future<void> _carregarPedidos() async {
    setState(() => _carregando = true);
    try {
      // Só pedidos com entrega pendente ou parcial; backend já limita a 20
      final params = <String, dynamic>{'statusRetirada': 'Pendente,Parcial'};
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarModalRetirada(Map<String, dynamic> pedido) {
    showDialog<void>(
      context: context,
      builder: (_) => ModalRetirada(
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
                          itemBuilder: (_, i) => CardPedidoRetirada(
                            pedido: _pedidos[i],
                            onRegistrarRetirada: () => _mostrarModalRetirada(_pedidos[i]),
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
            child: Align(
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
            leading: const Icon(Icons.people_outline),
            title: const Text('Clientes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaListaClientes()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Pedidos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaPedidos()),
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
            title: const Text('Configurações'),
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair', style: TextStyle(color: Colors.red)),
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
