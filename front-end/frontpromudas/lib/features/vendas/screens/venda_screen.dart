import 'package:flutter/material.dart';
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

  // Lista que vai alimentar a sua tabela de vendas
  List<Map<String, dynamic>> _carrinho = [];

  /// Inicializa a tela com o consumidor padrão já selecionado automaticamente.
  @override
  void initState() {
    super.initState();
    // Assim que a tela abre, o cliente padrão já é selecionado automaticamente
    _clienteSelecionado = _consumidorPadrao;
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
                carrinho: _carrinho,
                onRemoverItem: (itemParaRemover) {
                  setState(() {
                    _carrinho.removeWhere(
                      (prod) => prod['id'] == itemParaRemover['id'],
                    );
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

  /// Exibe o modal (bottom sheet) para pesquisar e trocar o cliente da venda.
  /// Ao confirmar a seleção, atualiza [_clienteSelecionado] no estado da tela.
  void _mostrarBuscaClienteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Usamos o widget extraído aqui!
        return BuscaClienteModal(
          onClienteSelecionado: (clienteEscolhido) {
            // Quando o modal avisar que o cliente foi selecionado,
            // atualizamos o estado da tela principal.
            setState(() {
              _clienteSelecionado = clienteEscolhido;
            });
          },
        );
      },
    );
  }

  /// Adiciona um produto ao carrinho. Se o produto já existir, incrementa a quantidade
  /// e recalcula o total. Caso contrário, insere o item com quantidade 1.
  void _adicionarAoCarrinho(Map<String, dynamic> produto) {
    setState(() {
      // Procura se o produto já está no carrinho
      final index = _carrinho.indexWhere((item) => item['id'] == produto['id']);

      if (index != -1) {
        // Se o produto já existe, aumenta a quantidade e atualiza o total
        _carrinho[index]['quantidade']++;
        _carrinho[index]['total'] =
            _carrinho[index]['quantidade'] * _carrinho[index]['preco'];
      } else {
        // Se é a primeira vez, adiciona na lista com quantidade 1
        _carrinho.add({
          'id': produto['id'],
          'nome': produto['nome'],
          'preco': produto['preco'],
          'quantidade': 1,
          'total':
              produto['preco'], // O total inicial é o próprio preço unitário
        });
      }
    });
  }
}
