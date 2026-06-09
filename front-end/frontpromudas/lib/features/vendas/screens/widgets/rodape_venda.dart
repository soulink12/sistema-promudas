import 'package:flutter/material.dart';
import '../../../../core/services/produto_service.dart';

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

/// Estado do RodapeVenda. Mantém o controller do campo de busca e a lista de produtos.
class _RodapeVendaState extends State<RodapeVenda> {
  // Controller do campo de pesquisa; inicializado pelo fieldViewBuilder do Autocomplete
  late TextEditingController _pesquisaProdutoController;

  List<Map<String, dynamic>> _produtos = [];
  bool _carregando = true;
  String? _erroCarregamento;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  Future<void> _carregarProdutos() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final produtos = await ProdutoService().listar();
      setState(() {
        _produtos = produtos;
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erroCarregamento = 'Não foi possível carregar os produtos.';
        _carregando = false;
      });
    }
  }

  /// Interpreta o texto digitado no formato "QTDxID" ou apenas "ID".
  /// Busca o produto pelo id na lista carregada da API.
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

    final produto = _produtos.firstWhere(
      (p) => p['id'] == id,
      orElse: () => <String, dynamic>{},
    );

    if (produto.isEmpty) return;

    widget.onProdutoSelecionado(produto, quantidade);
    _pesquisaProdutoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_carregando)
            const LinearProgressIndicator()
          else if (_erroCarregamento != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _erroCarregamento!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _carregarProdutos,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Autocomplete<Map<String, dynamic>>(
                  optionsViewOpenDirection: OptionsViewOpenDirection.up,
                  optionsBuilder: (TextEditingValue valorDigitado) {
                    if (valorDigitado.text.isEmpty || _produtos.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    final busca = valorDigitado.text.toLowerCase();
                    return _produtos.where((produto) {
                      final nome = produto['nome'].toString().toLowerCase();
                      final id = produto['id'].toString();
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
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            hintText: 'Nome, Cód. ou QTDxID (ex: 10x1)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: cs.surface,
                          ),
                          // onEditingComplete fecha o dropdown do Autocomplete
                          onEditingComplete: onEditingComplete,
                          // onSubmitted processa e adiciona ao carrinho
                          onSubmitted: _processarEntrada,
                        );
                      },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
