import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';
import 'dialog_ajuste.dart';

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
  // Callback acionado ao pressionar o botão ou F12 para finalizar o pedido
  final VoidCallback onFinalizarPedido;
  // Callback para abrir o diálogo de observações do pedido
  final VoidCallback onAdicionarObservacoes;
  // Indica se já há observações preenchidas (muda o rótulo/ícone do botão)
  final bool temObservacoes;
  // Valor do ajuste em R$ (negativo = desconto, positivo = acréscimo)
  final double ajuste;
  // Descrição exibida na tela (ex: "Desconto 10%")
  final String? descricaoAjuste;
  // Indica se o ajuste atual é percentual (para pré-preencher o diálogo corretamente)
  final bool ehPercentualAjuste;
  // Percentual com sinal armazenado no serviço (usado apenas quando ehPercentualAjuste = true)
  final double percentualAjuste;
  // Callback para aplicar um ajuste ao pedido
  final Function(double valor, String descricao, {bool ehPercentual}) onAplicarAjuste;
  // Callback para remover o ajuste atual
  final VoidCallback onRemoverAjuste;

  const FormularioVendaWidget({
    super.key,
    required this.carrinho,
    required this.onRemoverItem,
    required this.onAlterarQuantidade,
    required this.onAlterarPreco,
    required this.onFinalizarPedido,
    required this.onAdicionarObservacoes,
    this.temObservacoes = false,
    this.ajuste = 0.0,
    this.descricaoAjuste,
    this.ehPercentualAjuste = false,
    this.percentualAjuste = 0.0,
    required this.onAplicarAjuste,
    required this.onRemoverAjuste,
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
      cor = CoresSemanticas.desconto;
      icone = Icons.arrow_downward_rounded;
      tooltipOriginal = 'Sistema: ${formatarMoeda(precoOriginal)}';
    } else if (preco > precoOriginal) {
      cor = CoresSemanticas.acrescimo;
      icone = Icons.arrow_upward_rounded;
      tooltipOriginal = 'Sistema: ${formatarMoeda(precoOriginal)}';
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
          Expanded(
            child: Center(
              child: Text(
                'Nenhum produto adicionado ainda.\nUtilize a barra de pesquisa no rodapé.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
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
                  headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHighest),
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
                            formatarMoeda(item['total'] as double),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: CoresSemanticas.erro,
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

        // Total geral e botão de finalização — exibidos apenas quando há itens
        if (widget.carrinho.isNotEmpty) _rodapeTotalPedido(context),
        if (widget.carrinho.isNotEmpty) _botaoFinalizar(context),
      ],
    );
  }

  /// Exibe subtotal, ajuste (quando aplicado) e total final.
  /// Toque para abrir o diálogo de desconto/acréscimo.
  Widget _rodapeTotalPedido(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtotal = widget.carrinho.fold<double>(
      0,
      (soma, item) => soma + (item['total'] as double),
    );
    final totalFinal = subtotal + widget.ajuste;
    final temAjuste = widget.ajuste != 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (temAjuste) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Subtotal:',
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Text(formatarMoeda(subtotal),
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  widget.ajuste < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 13,
                  color: widget.ajuste < 0
                      ? CoresSemanticas.desconto
                      : CoresSemanticas.acrescimo,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.descricaoAjuste ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.ajuste < 0
                        ? CoresSemanticas.desconto
                        : CoresSemanticas.acrescimo,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.ajuste < 0 ? '-' : '+'}${formatarMoeda(widget.ajuste.abs())}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.ajuste < 0
                        ? CoresSemanticas.desconto
                        : CoresSemanticas.acrescimo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Tooltip(
            message: 'Clique para adicionar desconto ou acréscimo',
            child: InkWell(
              onTap: () => _abrirDialogAjuste(subtotal),
              borderRadius: BorderRadius.circular(4),
              hoverColor: cs.primary.withAlpha(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total do Pedido:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatarMoeda(totalFinal),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined, size: 15, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre o diálogo para configurar desconto ou acréscimo sobre o [subtotal].
  void _abrirDialogAjuste(double subtotal) {
    showDialog<void>(
      context: context,
      builder: (_) => DialogAjuste(
        subtotal: subtotal,
        ajusteAtual: widget.ajuste,
        ehPercentualAtual: widget.ehPercentualAjuste,
        percentualAtual: widget.percentualAjuste,
        onAplicar: widget.onAplicarAjuste,
        onRemover: widget.onRemoverAjuste,
      ),
    );
  }

  /// Linha de ações do rodapé: observações à esquerda e finalizar à direita.
  /// O botão de finalização indica o atalho F12 na label.
  Widget _botaoFinalizar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: widget.onAdicionarObservacoes,
            icon: Icon(widget.temObservacoes
                ? Icons.edit_note
                : Icons.note_add_outlined),
            label: Text(widget.temObservacoes
                ? 'Editar observações'
                : 'Adicionar observações'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onFinalizarPedido,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Finalizar Pedido  •  F12'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
