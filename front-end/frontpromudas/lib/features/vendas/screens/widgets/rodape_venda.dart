import 'package:flutter/material.dart';
import '../../../../core/mock/dados_mock.dart';

/// Widget do rodapé da tela de venda.
/// Exibe a barra de pesquisa de produtos (com autocomplete) e o atalho de finalização.
class RodapeVenda extends StatefulWidget {
  // Callback chamado quando o operador seleciona um produto na busca
  final Function(Map<String, dynamic>) onProdutoSelecionado;

  const RodapeVenda({
    super.key,
    required this.onProdutoSelecionado,
  });

  @override
  State<RodapeVenda> createState() => _RodapeVendaState();
}

/// Estado do RodapeVenda. Mantém o controller do campo de busca para limpá-lo após a seleção.
class _RodapeVendaState extends State<RodapeVenda> {
  // Controller do campo de pesquisa; inicializado pelo fieldViewBuilder do Autocomplete
  late TextEditingController _pesquisaProdutoController;

  /// Constrói o rodapé fixo com a barra de pesquisa de produtos (Autocomplete)
  /// e o atalho de teclado para finalizar a venda.
  // TODO: substituir por SQLite — trocar DadosMock().produtosMock por consulta ao banco
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.green[100],
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Envolvemos no Expanded para o TextField não quebrar a tela na horizontal
          Expanded(
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue valorDigitado) {
                if (valorDigitado.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                final busca = valorDigitado.text.toLowerCase();
                // TODO: substituir por SQLite — buscar produtos do banco em vez do mock
                return DadosMock().produtosMock.where((produto) {
                  final nome = produto['nome'].toString().toLowerCase();
                  final id = produto['id'].toString().toLowerCase();
                  return nome.contains(busca) || id.contains(busca);
                });
              },
              displayStringForOption: (Map<String, dynamic> p) => p['nome'],

              onSelected: (Map<String, dynamic> produtoEscolhido) {
                widget.onProdutoSelecionado(produtoEscolhido);

                // Limpa o campo de texto para o caixa poder bipar/pesquisar o próximo item
                _pesquisaProdutoController.clear();
              },

              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    // Salva o controller para poder limpá-lo após a seleção do produto
                    _pesquisaProdutoController = controller;

                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        hintText: 'Pesquisar Produto (Nome ou Cód.)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onEditingComplete: onEditingComplete,
                    );
                  },
            ),
          ),
          const SizedBox(width: 16), // Dá um espaço entre a barra de pesquisa e o texto
          const Text(
            'F12 Finalizar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
