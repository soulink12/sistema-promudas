import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/carrinho_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../clientes/screens/clientes_screen.dart';
import 'widgets/detalhes_app_bar.dart';
import 'widgets/modal_busca_cliente.dart';
import 'widgets/formulario_venda.dart';
import 'widgets/rodape_venda.dart';
import 'widgets/modal_pagamento.dart';

/// Tela principal de registro de venda (PDV).
/// Gerencia o estado do carrinho de compras e do cliente selecionado.
class TelaVenda extends StatefulWidget {
  const TelaVenda({super.key});

  @override
  State<TelaVenda> createState() => _TelaVendaState();
}

class _TelaVendaState extends State<TelaVenda> {
  // Cliente padrão para venda direta — id=1 reservado no banco para "Consumidor"
  final Map<String, dynamic> _consumidorPadrao = {
    'id': 1,
    'nome': 'Consumidor',
    'cpf': 'Não informado',
    'telefone': 'Não informado',
  };

  Map<String, dynamic>? _clienteSelecionado;
  final _carrinhoService = CarrinhoService();

  // Bloqueia interações enquanto o pedido está sendo enviado à API
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _clienteSelecionado = _consumidorPadrao;
    HardwareKeyboard.instance.addHandler(_onTecla);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onTecla);
    super.dispose();
  }

  /// Intercepta F5 e F12 globalmente na tela, independente de qual campo tem foco.
  bool _onTecla(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_salvando) return false;
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _mostrarBuscaClienteModal(context);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f12) {
      _finalizarPedido();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[100],
        titleSpacing: 8,
        title: DetalhesAppBar(
          clienteSelecionado: _clienteSelecionado,
          onTap: _salvando ? null : () => _mostrarBuscaClienteModal(context),
        ),
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: FormularioVendaWidget(
                    carrinho: _carrinhoService.itens,
                    ajuste: _carrinhoService.ajuste,
                    descricaoAjuste: _carrinhoService.descricaoAjuste,
                    ehPercentualAjuste: _carrinhoService.ehPercentualAjuste,
                    percentualAjuste: _carrinhoService.percentualAjuste,
                    onRemoverItem: (itemParaRemover) {
                      setState(() {
                        _carrinhoService.removerItem(itemParaRemover['id']);
                      });
                    },
                    onAlterarQuantidade: (item, novaQtd) {
                      setState(() {
                        _carrinhoService.alterarQuantidade(
                            item['id'], novaQtd);
                      });
                    },
                    onAlterarPreco: (item, novoPreco) {
                      setState(() {
                        _carrinhoService.alterarPreco(item['id'], novoPreco);
                      });
                    },
                    onFinalizarPedido: _finalizarPedido,
                    onAplicarAjuste: (valor, descricao,
                        {ehPercentual = false}) {
                      setState(() {
                        _carrinhoService.aplicarAjuste(valor, descricao,
                            ehPercentual: ehPercentual);
                      });
                    },
                    onRemoverAjuste: () {
                      setState(() {
                        _carrinhoService.removerAjuste();
                      });
                    },
                  ),
                ),
                RodapeVenda(onProdutoSelecionado: _adicionarAoCarrinho),
              ],
            ),
          ),

          // Overlay de carregamento enquanto o pedido é enviado
          if (_salvando) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final nomeUsuario =
        AuthService.usuario?['nome'] as String? ?? 'Usuário';

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.green[700]),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistema Promudas',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nomeUsuario,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('PDV'),
            selected: true,
            selectedColor: Colors.green[700],
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Clientes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TelaListaClientes()),
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

  void _mostrarBuscaClienteModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: BuscaClienteModal(
                onClienteSelecionado: (clienteEscolhido) {
                  setState(() {
                    _clienteSelecionado = clienteEscolhido;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _adicionarAoCarrinho(Map<String, dynamic> produto, int quantidade) {
    setState(() {
      _carrinhoService.adicionarItem(produto, quantidade: quantidade);
    });
  }

  void _finalizarPedido() {
    if (_carrinhoService.itens.isEmpty || _salvando) return;

    showDialog<void>(
      context: context,
      builder: (_) => ModalPagamento(
        totalPedido: _carrinhoService.totalComAjuste,
        onConfirmar: _registrarPedido,
      ),
    );
  }

  /// Envia o pedido à API: cria o pedido com os itens e registra cada pagamento.
  /// Troco é ignorado — o valor de cada parcela é capeado pelo saldo restante.
  Future<void> _registrarPedido(
      List<Map<String, dynamic>> pagamentos) async {
    setState(() => _salvando = true);

    final itens = _carrinhoService.itens;
    final cliente = _clienteSelecionado!;
    final ajuste = _carrinhoService.ajuste;

    try {
      // 1. Cria o pedido com os itens
      final respostaPedido = await ApiService.dio.post('/pedidos', data: {
        'cliente_id': cliente['id'],
        'valor_total': _carrinhoService.totalComAjuste,
        if (ajuste != 0.0) 'ajuste': ajuste,
        'itens': itens
            .map((item) => {
                  'produto_id': item['id'],
                  'quantidade': item['quantidade'],
                  'valor_unitario': item['preco'],
                })
            .toList(),
      });

      final pedidoId = respostaPedido.data['data']['id'] as int;

      // 2. Registra cada forma de pagamento, capeando pelo saldo restante (descarta troco)
      double restante = _carrinhoService.totalComAjuste;
      for (final p in pagamentos) {
        if (restante <= 0.005) break;
        final valorPago =
            (p['valor'] as double).clamp(0.0, restante);
        await ApiService.dio.post('/pagamentos', data: {
          'pedido_id': pedidoId,
          'valor_pago': valorPago,
          'forma_pagamento': p['forma'],
          'data_pagamento': DateTime.now().toUtc().toIso8601String(),
        });
        restante -= valorPago;
      }

      // 3. Reinicia o estado da tela
      setState(() {
        _carrinhoService.limpar();
        _clienteSelecionado = _consumidorPadrao;
        _salvando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido registrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar pedido. Tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
