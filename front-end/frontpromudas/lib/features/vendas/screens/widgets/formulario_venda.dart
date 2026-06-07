import 'package:flutter/material.dart';

/// Widget que exibe a tabela de itens adicionados à venda (carrinho).
/// Permite edição inline de quantidade e preço unitário por item.
/// Preços alterados em relação ao valor do sistema são destacados visualmente.
class FormularioVendaWidget extends StatefulWidget {
  // Recebe a lista de itens da tela principal
  final List<Map<String, dynamic>> carrinho;
  // Callback para avisar a tela principal qual item deve ser apagado
  final Function(Map<String, dynamic>) onRemoverItem;
  // Callback para atualizar a quantidade de um item
  final Function(Map<String, dynamic>, int novaQtd) onAlterarQuantidade;
  // Callback para atualizar o preço unitário de um item
  final Function(Map<String, dynamic>, double novoPreco) onAlterarPreco;

  const FormularioVendaWidget({
    super.key,
    required this.carrinho,
    required this.onRemoverItem,
    required this.onAlterarQuantidade,
    required this.onAlterarPreco,
  });

  @override
  State<FormularioVendaWidget> createState() => _FormularioVendaWidgetState();
}

class _FormularioVendaWidgetState extends State<FormularioVendaWidget> {
  // Controllers e FocusNodes indexados pelo id do item
  final Map<dynamic, TextEditingController> _qtdControllers = {};
  final Map<dynamic, TextEditingController> _precoControllers = {};
  final Map<dynamic, FocusNode> _qtdFocusNodes = {};
  final Map<dynamic, FocusNode> _precoFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _sincronizarControllers(widget.carrinho);
  }

  @override
  void didUpdateWidget(FormularioVendaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizarControllers(widget.carrinho);
  }

  /// Cria controllers/focusNodes para novos itens, sincroniza valores para itens
  /// existentes (somente se o campo não estiver com foco) e descarta os removidos.
  void _sincronizarControllers(List<Map<String, dynamic>> itens) {
    for (final item in itens) {
      final id = item['id'];
      final qtdTexto = '${item['quantidade']}';
      final precoTexto = (item['preco'] as double).toStringAsFixed(2);

      // Quantidade
      if (!_qtdControllers.containsKey(id)) {
        _qtdControllers[id] = TextEditingController(text: qtdTexto);
        _qtdFocusNodes[id] = FocusNode();
      } else if (!_qtdFocusNodes[id]!.hasFocus &&
          _qtdControllers[id]!.text != qtdTexto) {
        _qtdControllers[id]!.text = qtdTexto;
      }

      // Preço
      if (!_precoControllers.containsKey(id)) {
        _precoControllers[id] = TextEditingController(text: precoTexto);
        _precoFocusNodes[id] = FocusNode();
      } else if (!_precoFocusNodes[id]!.hasFocus &&
          _precoControllers[id]!.text != precoTexto) {
        _precoControllers[id]!.text = precoTexto;
      }
    }

    // Remove controllers de itens que saíram do carrinho
    final idsAtivos = itens.map((i) => i['id']).toSet();
    for (final id in _qtdControllers.keys.toList()) {
      if (!idsAtivos.contains(id)) {
        _qtdControllers.remove(id)!.dispose();
        _precoControllers.remove(id)!.dispose();
        _qtdFocusNodes.remove(id)!.dispose();
        _precoFocusNodes.remove(id)!.dispose();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _qtdControllers.values) c.dispose();
    for (final c in _precoControllers.values) c.dispose();
    for (final f in _qtdFocusNodes.values) f.dispose();
    for (final f in _precoFocusNodes.values) f.dispose();
    super.dispose();
  }

  /// Constrói o campo inline de quantidade para um item.
  Widget _celulaQtd(Map<String, dynamic> item) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: _qtdControllers[item['id']],
        focusNode: _qtdFocusNodes[item['id']],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (texto) {
          final novaQtd = int.tryParse(texto.trim());
          if (novaQtd != null) widget.onAlterarQuantidade(item, novaQtd);
        },
      ),
    );
  }

  /// Constrói o campo inline de preço unitário para um item.
  /// Quando o preço difere do preço original do sistema, aplica destaque visual:
  ///   - Azul + seta para baixo: preço com desconto
  ///   - Laranja + seta para cima: preço acima do sistema
  Widget _celulaPreco(Map<String, dynamic> item) {
    final preco = item['preco'] as double;
    final precoOriginal = item['precoOriginal'] as double;

    Color? cor;
    IconData? icone;
    String? tooltipOriginal;

    if (preco < precoOriginal) {
      cor = Colors.blue[700];
      icone = Icons.arrow_downward_rounded;
      tooltipOriginal = 'Sistema: R\$ ${precoOriginal.toStringAsFixed(2)}';
    } else if (preco > precoOriginal) {
      cor = Colors.orange[800];
      icone = Icons.arrow_upward_rounded;
      tooltipOriginal = 'Sistema: R\$ ${precoOriginal.toStringAsFixed(2)}';
    }

    final campo = SizedBox(
      width: 88,
      child: TextField(
        controller: _precoControllers[item['id']],
        focusNode: _precoFocusNodes[item['id']],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: cor,
          fontWeight: cor != null ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          border: const OutlineInputBorder(),
          // Borda colorida quando o preço está alterado
          enabledBorder: cor != null
              ? OutlineInputBorder(
                  borderSide: BorderSide(color: cor, width: 1.5))
              : null,
          prefixText: 'R\$ ',
          prefixStyle: TextStyle(color: cor, fontSize: 12),
        ),
        onSubmitted: (texto) {
          final novoPreco =
              double.tryParse(texto.trim().replaceAll(',', '.'));
          if (novoPreco != null) widget.onAlterarPreco(item, novoPreco);
        },
      ),
    );

    if (icone == null) return campo;

    // Ícone com tooltip mostrando o preço original do sistema
    return Tooltip(
      message: tooltipOriginal!,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 2),
          campo,
        ],
      ),
    );
  }

  /// Constrói a tabela de itens da venda ou uma mensagem de carrinho vazio.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título da seção
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Itens da Venda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(),

        // Exibe mensagem de orientação quando o carrinho está vazio
        if (widget.carrinho.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Nenhum produto adicionado ainda.\nUtilize a barra de pesquisa no rodapé.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        else
          // Tabela com scroll vertical para suportar muitos itens
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Variedade / Produto', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Qtd.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Preço Unit.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  // Gera uma linha na tabela para cada item do carrinho
                  rows: widget.carrinho.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text('#${item['id']}')),
                        DataCell(Text('${item['nome']}')),
                        DataCell(_celulaQtd(item)),
                        DataCell(_celulaPreco(item)),
                        DataCell(
                          Text(
                            'R\$ ${(item['total'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Remover item',
                            onPressed: () {
                              // Delega a remoção para a tela principal via callback,
                              // mantendo o estado centralizado em TelaVenda
                              widget.onRemoverItem(item);
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

        // Total geral do pedido — exibido apenas quando há itens no carrinho
        if (widget.carrinho.isNotEmpty) _rodapeTotalPedido(),
      ],
    );
  }

  /// Soma os totais de todos os itens e exibe no canto inferior direito.
  Widget _rodapeTotalPedido() {
    final totalPedido = widget.carrinho.fold<double>(
      0,
      (soma, item) => soma + (item['total'] as double),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(top: BorderSide(color: Colors.green.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'Total do Pedido:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Text(
            'R\$ ${totalPedido.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }
}
