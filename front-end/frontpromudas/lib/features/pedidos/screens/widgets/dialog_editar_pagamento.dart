import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/forma_pagamento_service.dart';

/// Diálogo para editar um pagamento (valor e forma).
/// Retorna via `Navigator.pop` um mapa `{valor_pago, forma_pagamento}` ao salvar,
/// ou `null` se cancelado. Não faz a chamada à API — quem chama persiste.
class DialogEditarPagamento extends StatefulWidget {
  final Map<String, dynamic> pagamento;

  const DialogEditarPagamento({super.key, required this.pagamento});

  @override
  State<DialogEditarPagamento> createState() => _DialogEditarPagamentoState();
}

class _DialogEditarPagamentoState extends State<DialogEditarPagamento> {
  late final TextEditingController _valorCtrl;
  String? _formaSelecionada;
  List<Map<String, dynamic>> _formas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final valor = _toDouble(widget.pagamento['valor_pago']);
    _valorCtrl = TextEditingController(text: valor.toStringAsFixed(2));
    _formaSelecionada = widget.pagamento['forma_pagamento'] as String?;
    _carregarFormas();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarFormas() async {
    try {
      final todas = await FormaPagamentoService().listar();
      // Só formas reais (crediário/posterior não aparece na lista de pagamentos)
      final reais =
          todas.where((f) => f['pagamentoPosterior'] != true).toList();

      // Garante que a forma atual esteja disponível mesmo se inativa
      if (_formaSelecionada != null &&
          !reais.any((f) => f['nome'] == _formaSelecionada)) {
        reais.add({'nome': _formaSelecionada});
      }

      setState(() {
        _formas = reais;
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar as formas de pagamento.';
        _carregando = false;
      });
    }
  }

  void _salvar() {
    final valor =
        double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (valor <= 0 || _formaSelecionada == null) return;

    Navigator.pop(context, <String, dynamic>{
      'valor_pago': valor,
      'forma_pagamento': _formaSelecionada,
    });
  }

  bool get _podeSalvar {
    final valor =
        double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    return valor > 0 && _formaSelecionada != null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Pagamento'),
      content: SizedBox(
        width: 380,
        child: _carregando
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _erro != null
                ? Text(_erro!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _valorCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Valor pago',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _formaSelecionada,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                          border: OutlineInputBorder(),
                        ),
                        items: _formas
                            .map((f) => DropdownMenuItem(
                                  value: f['nome'] as String,
                                  child: Text(f['nome'] as String),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _formaSelecionada = v),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_carregando || !_podeSalvar) ? null : _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
