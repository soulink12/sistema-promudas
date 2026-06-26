import 'package:flutter/material.dart';
import '../../../../core/services/produto_service.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/observador_rotas.dart';

/// Widget do rodapé da tela de venda.
/// Exibe a barra de pesquisa de produtos (com autocomplete) e o atalho de finalização.
///
/// Fluxo de uso:
///   1. Operador digita nome ou código → sugestões aparecem
///   2. Operador seleciona uma sugestão → campo mostra o nome do produto
///   3. Operador prefixa "QTD*" ou "QTDx" (ex: "100*mudas de pimenta" = 100 unidades)
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
class _RodapeVendaState extends State<RodapeVenda> with RouteAware {
  // Controller do campo de pesquisa; inicializado pelo fieldViewBuilder do Autocomplete
  late TextEditingController _pesquisaProdutoController;

  List<Map<String, dynamic>> _produtos = [];
  bool _carregando = true;
  String? _erroCarregamento;

  // Suprime o "Enter" que apenas confirma a seleção de um produto na lista — a
  // quantidade é digitada depois. Limpado no frame seguinte à seleção.
  bool _selecionandoOpcao = false;
  // Nome do produto recém-selecionado: enquanto o campo mostrar exatamente esse
  // nome, o dropdown fica fechado, para o Enter adicionar (qtd 1) sem reselecionar.
  String? _nomeSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Assina o observador para reagir quando o PDV volta ao topo da pilha.
    final rota = ModalRoute.of(context);
    if (rota != null) observadorRotas.subscribe(this, rota);
  }

  @override
  void dispose() {
    observadorRotas.unsubscribe(this);
    super.dispose();
  }

  /// Chamado quando uma tela empilhada por cima (ex.: Configurações) é fechada
  /// e o PDV volta a ficar visível. Recarrega os produtos para refletir
  /// alterações de catálogo (ex.: produto desativado deve sumir da pesquisa).
  @override
  void didPopNext() {
    _recarregarSilencioso();
  }

  /// Atualiza a lista sem exibir o indicador de carregamento; em caso de falha,
  /// mantém a lista atual para não atrapalhar a venda em andamento.
  Future<void> _recarregarSilencioso() async {
    try {
      final produtos = await ProdutoService().listar();
      if (mounted) setState(() => _produtos = produtos);
    } catch (_) {
      // Mantém a lista atual.
    }
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

  /// Interpreta o texto digitado no formato "QTD*PRODUTO" ou "QTDxPRODUTO"
  /// (separador `*` ou `x` após o número), ou apenas o produto (quantidade 1).
  /// A parte do produto pode ser o nome (ex.: "mudas de pimenta") ou o código.
  void _processarEntrada(String texto) {
    // Ignora o Enter que só confirmou a seleção na lista; a quantidade vem depois.
    if (_selecionandoOpcao) return;

    final trimmed = texto.trim();
    if (trimmed.isEmpty) return;

    int quantidade = 1;
    String parteProduto = trimmed;

    // Número inicial + separador (* ou x) + produto. O produto é o resto da
    // string, então nomes com 'x' no meio não atrapalham (só o 1º separador conta).
    final match = RegExp(r'^(\d+)\s*[x*]\s*(.+)$').firstMatch(trimmed);
    if (match != null) {
      quantidade = int.tryParse(match.group(1)!) ?? 1;
      parteProduto = match.group(2)!.trim();
    }

    if (quantidade <= 0 || parteProduto.isEmpty) return;

    final produto = _encontrarProduto(parteProduto);
    if (produto.isEmpty) return;

    widget.onProdutoSelecionado(produto, quantidade);
    _pesquisaProdutoController.clear();
    _nomeSelecionado = null;
  }

  /// Resolve o produto pela parte digitada: por código (quando numérico) ou
  /// pelo nome (correspondência exata, sem diferenciar maiúsculas/minúsculas).
  Map<String, dynamic> _encontrarProduto(String termo) {
    final idNumerico = int.tryParse(termo);
    if (idNumerico != null) {
      final porId = _produtos.firstWhere(
        (p) => p['id'] == idNumerico,
        orElse: () => <String, dynamic>{},
      );
      if (porId.isNotEmpty) return porId;
    }

    final alvo = termo.toLowerCase();
    return _produtos.firstWhere(
      (p) => p['nome'].toString().toLowerCase() == alvo,
      orElse: () => <String, dynamic>{},
    );
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
                  const Icon(Icons.error_outline,
                      color: CoresSemanticas.erro, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _erroCarregamento!,
                      style: const TextStyle(
                          color: CoresSemanticas.erro, fontSize: 12),
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
                    // Logo após selecionar, o campo mostra o nome exato — não
                    // reabrir a lista, senão o Enter para confirmar a quantidade
                    // reselecionaria o produto em vez de adicioná-lo.
                    if (valorDigitado.text == _nomeSelecionado) {
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
                    // Marca que este Enter foi só para selecionar (não adicionar).
                    _selecionandoOpcao = true;
                    // Campo mostra o nome do produto; cursor no início para o
                    // operador prefixar a quantidade (ex.: "100*mudas de pimenta").
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final nome = produtoEscolhido['nome'].toString();
                      _nomeSelecionado = nome;
                      _pesquisaProdutoController.text = nome;
                      _pesquisaProdutoController.selection =
                          TextSelection.fromPosition(
                        const TextPosition(offset: 0),
                      );
                      _selecionandoOpcao = false;
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
                            hintText: 'Nome, Cód. ou QTD*Produto (ex: 100*mudas de pimenta)',
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
