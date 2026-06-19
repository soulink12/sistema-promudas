import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';

/// Diálogo para configurar um desconto ou acréscimo sobre o [subtotal] do
/// pedido. Suporta valor fixo (R$) ou percentual (%), com preview do total em
/// tempo real. Ao confirmar, chama [onAplicar] com o valor sinalizado
/// (negativo = desconto) e a descrição; [onRemover] limpa o ajuste atual.
///
/// Usado pelo `FormularioVendaWidget` (toque no "Total do Pedido").
class DialogAjuste extends StatefulWidget {
  final double subtotal;
  final double ajusteAtual;
  final bool ehPercentualAtual;
  final double percentualAtual;
  final Function(double valor, String descricao, {bool ehPercentual}) onAplicar;
  final VoidCallback onRemover;

  const DialogAjuste({
    super.key,
    required this.subtotal,
    required this.ajusteAtual,
    required this.ehPercentualAtual,
    required this.percentualAtual,
    required this.onAplicar,
    required this.onRemover,
  });

  @override
  State<DialogAjuste> createState() => _DialogAjusteState();
}

class _DialogAjusteState extends State<DialogAjuste> {
  late bool _ehDesconto;
  bool _ehPercentual = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ehDesconto = widget.ajusteAtual <= 0;
    _ehPercentual = widget.ehPercentualAtual;
    // Pré-preenche com o percentual bruto (ex: "10.0") quando for ajuste percentual,
    // ou com o valor em R$ absoluto quando for ajuste fixo
    if (widget.ehPercentualAtual && widget.percentualAtual != 0.0) {
      _ctrl = TextEditingController(
        text: widget.percentualAtual.abs().toStringAsFixed(1),
      );
    } else {
      _ctrl = TextEditingController(
        text: widget.ajusteAtual != 0.0
            ? widget.ajusteAtual.abs().toStringAsFixed(2)
            : '',
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _calcularAjuste() {
    final valor = double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0) return 0;
    if (_ehPercentual) {
      return widget.subtotal * valor / 100 * (_ehDesconto ? -1 : 1);
    }
    return valor * (_ehDesconto ? -1 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final ajustePreview = _calcularAjuste();
    final totalPreview = widget.subtotal + ajustePreview;

    return AlertDialog(
      title: const Text('Ajuste do Pedido'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seletor Desconto / Acréscimo
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Desconto'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Acréscimo'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
              ],
              selected: {_ehDesconto},
              onSelectionChanged: (v) =>
                  setState(() => _ehDesconto = v.first),
            ),
            const SizedBox(height: 12),
            // Seletor R$ / %
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('R\$')),
                ButtonSegment(value: true, label: Text('%')),
              ],
              selected: {_ehPercentual},
              onSelectionChanged: (v) =>
                  setState(() => _ehPercentual = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor',
                border: const OutlineInputBorder(),
                prefixText: _ehPercentual ? null : 'R\$ ',
                suffixText: _ehPercentual ? '%' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            // Preview em tempo real do total após o ajuste
            Builder(builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text(formatarMoeda(widget.subtotal)),
                      ],
                    ),
                    if (ajustePreview != 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _ehDesconto ? 'Desconto:' : 'Acréscimo:',
                            style: TextStyle(
                              color: _ehDesconto
                                  ? CoresSemanticas.desconto
                                  : CoresSemanticas.acrescimo,
                            ),
                          ),
                          Text(
                            '${ajustePreview < 0 ? '-' : '+'}${formatarMoeda(ajustePreview.abs())}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _ehDesconto
                                  ? CoresSemanticas.desconto
                                  : CoresSemanticas.acrescimo,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          formatarMoeda(totalPreview),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        // Remove qualquer ajuste existente
        TextButton(
          onPressed: () {
            widget.onRemover();
            Navigator.pop(context);
          },
          child: const Text('Limpar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final valor =
                double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
            if (valor > 0) {
              // Para percentual: envia o % com sinal; o serviço recalcula em R$
              // dinamicamente quando os itens mudarem.
              // Para fixo: envia o R$ com sinal diretamente.
              final sinalizado = valor * (_ehDesconto ? -1 : 1);
              final descricao = _ehPercentual
                  ? '${_ehDesconto ? 'Desconto' : 'Acréscimo'} ${valor.toStringAsFixed(1)}%'
                  : '${_ehDesconto ? 'Desconto' : 'Acréscimo'} ${formatarMoeda(valor)}';
              widget.onAplicar(sinalizado, descricao,
                  ehPercentual: _ehPercentual);
            }
            Navigator.pop(context);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
