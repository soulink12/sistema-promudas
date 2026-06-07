import 'package:flutter/material.dart';
import '../../../../core/mock/dados_mock.dart';

/// Widget do rodapé da tela de venda.
/// Exibe a barra de pesquisa de produtos (com autocomplete) e o atalho de finalização.
///
/// Fluxo de uso:
///   1. Operador digita nome ou código → sugestões aparecem
///   2. Operador seleciona uma sugestão → campo mostra só o id (ex: "1")
///   3. Operador pode editar para "QTDxID" (ex: "10x1" = 10 unidades do produto 1)
///   4. Operador pressiona Enter → item adicionado ao carrinho
class RodapeVenda extends StatefulWidget {
  // Callback chamado com o produto encontrado e a quantidade informada
  final Function(Map<String, dynamic> produto, int quantidade) onProdutoSelecionado;

  const RodapeVenda({
    super.key,
    required this.onProdutoSelecionado,
  });

  @override
  State<RodapeVenda> createState() => _RodapeVendaState();
}

/// Estado do RodapeVenda. Mantém o controller do campo de busca.
class _RodapeVendaState extends State<RodapeVenda> {
  // Controller do campo de pesquisa; inicializado pelo fieldViewBuilder do Autocomplete
  late TextEditingController _pesquisaProdutoController;

  /// Interpreta o texto digitado no formato "QTDxID" ou apenas "ID".
  /// Busca o produto pelo id, então chama o callback com produto e quantidade.
  // TODO: substituir por SQLite — buscar produto por id no banco em vez do mock
  void _processarEntrada(String texto) {
    final trimmed = texto.trim();
    if (trimmed.isEmpty) return;

    int quantidade = 1;
    int id;

    if (trimmed.contains('x')) {
      final partes = trimmed.split('x');
      // Formato inválido se não houver exatamente dois segmentos
      if (partes.length != 2) return;
      quantidade = int.tryParse(partes[0]) ?? 1;
      id = int.tryParse(partes[1]) ?? -1;
    } else {
      id = int.tryParse(trimmed) ?? -1;
    }

    if (id == -1 || quantidade <= 0) return;

    // TODO: substituir por SQLite — buscar produto por id no banco
    final lista = DadosMock().produtosMock;
    final produto = lista.firstWhere(
      (p) => p['id'] == id,
      orElse: () => {},
    );

    if (produto.isEmpty) return;

    widget.onProdutoSelecionado(produto, quantidade);
    _pesquisaProdutoController.clear();
  }

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
              optionsViewOpenDirection: OptionsViewOpenDirection.up,
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
                // Após o Autocomplete preencher o campo com o nome,
                // sobrescrevemos com apenas o id para o operador informar a quantidade
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pesquisaProdutoController.text =
                      produtoEscolhido['id'].toString();
                  _pesquisaProdutoController.selection =
                      TextSelection.fromPosition(
                    const TextPosition(offset: 0),
                  );
                });
              },

              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    // Salva o controller para manipulá-lo após a seleção
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
                        hintText: 'Nome, Cód. ou QTDxID (ex: 10x1)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      // onEditingComplete fecha o dropdown do Autocomplete
                      onEditingComplete: onEditingComplete,
                      // onSubmitted processa e adiciona ao carrinho
                      onSubmitted: _processarEntrada,
                    );
                  },
            ),
          ) // Dá um espaço entre a barra de pesquisa e o texto
        ],
      ),
    );
  }
}
