import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/carrinho_service.dart';
import 'widgets/detalhes_app_bar.dart';
import 'widgets/modal_busca_cliente.dart';
import 'widgets/formulario_venda.dart';
import 'widgets/rodape_venda.dart';

/// Tela principal de registro de venda (PDV).
/// Gerencia o estado do carrinho de compras e do cliente selecionado.
class TelaVenda extends StatefulWidget {
  const TelaVenda({super.key});

  @override
  State<TelaVenda> createState() => _TelaVendaState();
}

/// Estado da TelaVenda. Controla o cliente ativo, o carrinho e a pesquisa de produtos.
class _TelaVendaState extends State<TelaVenda> {
  // Define a estrutura do seu Consumidor Padrão
  // TODO: substituir por SQLite — buscar o cliente padrão (id=1) da tabela 'clientes'
  final Map<String, dynamic> _consumidorPadrao = {
    'id': 1,
    'nome': 'Consumidor',
    'cpf': 'Não informado',
    'telefone': 'Não informado',
  };

  // Variável que controla qual cliente está ativo na venda atual
  Map<String, dynamic>? _clienteSelecionado;

  // Serviço que gerencia os itens do carrinho
  final _carrinhoService = CarrinhoService();

  /// Inicializa a tela com o consumidor padrão e registra o handler de F12.
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

  /// Constrói a estrutura principal da tela: AppBar com dados do cliente,
  /// tabela de itens no corpo e rodapé com busca de produtos.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[100],
        titleSpacing: 16,
        // Passamos o cliente e dizemos o que fazer ao clicar
        title: DetalhesAppBar(
          clienteSelecionado: _clienteSelecionado,
          onTap: () {
            // Quando o usuário clicar no AppBar, chamamos a função que abre o modal
            _mostrarBuscaClienteModal(context);
          },
        ),
      ),
      body: Padding(
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
                    _carrinhoService.alterarQuantidade(item['id'], novaQtd);
                  });
                },
                onAlterarPreco: (item, novoPreco) {
                  setState(() {
                    _carrinhoService.alterarPreco(item['id'], novoPreco);
                  });
                },
                onFinalizarPedido: _finalizarPedido,
                onAplicarAjuste: (valor, descricao, {ehPercentual = false}) {
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
    );
  }

  /// Exibe o popup de busca de clientes ancorado abaixo da AppBar, alinhado à esquerda.
  /// Ao confirmar a seleção, atualiza [_clienteSelecionado] no estado da tela.
  void _mostrarBuscaClienteModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            // Posiciona logo abaixo da AppBar, respeitando a status bar
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

  /// Delega a adição do produto ao [CarrinhoService] e solicita rebuild da tela.
  void _adicionarAoCarrinho(Map<String, dynamic> produto, int quantidade) {
    setState(() {
      _carrinhoService.adicionarItem(produto, quantidade: quantidade);
    });
  }

  /// Imprime no console os dados do cliente e do pedido.
  /// TODO: substituir pelo fluxo real de persistência da venda no SQLite
  void _finalizarPedido() {
    if (_carrinhoService.itens.isEmpty) return;

    final itens = _carrinhoService.itens;
    final cliente = _clienteSelecionado!;

    debugPrint('╔══════════════════════════════════════');
    debugPrint('║  PEDIDO FINALIZADO');
    debugPrint('╠══════════════════════════════════════');
    debugPrint('║  CLIENTE');
    debugPrint('║    Nome:     ${cliente['nome']}');
    debugPrint('║    CPF:      ${cliente['cpf']}');
    debugPrint('║    Telefone: ${cliente['telefone']}');
    debugPrint('╠══════════════════════════════════════');
    debugPrint('║  ITENS');
    for (final item in itens) {
      final preco = (item['preco'] as double).toStringAsFixed(2);
      final total = (item['total'] as double).toStringAsFixed(2);
      debugPrint('║    [#${item['id']}] ${item['nome']}');
      debugPrint('║         ${item['quantidade']} × R\$ $preco = R\$ $total');
    }
    debugPrint('╠══════════════════════════════════════');
    if (_carrinhoService.ajuste != 0.0) {
      debugPrint('║  SUBTOTAL: R\$ ${_carrinhoService.subtotal.toStringAsFixed(2)}');
      debugPrint('║  ${_carrinhoService.descricaoAjuste}: R\$ ${_carrinhoService.ajuste.toStringAsFixed(2)}');
    }
    debugPrint('║  TOTAL: R\$ ${_carrinhoService.totalComAjuste.toStringAsFixed(2)}');
    debugPrint('╚══════════════════════════════════════');
  }
}
