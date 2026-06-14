import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class TelaFormasPagamento extends StatefulWidget {
  const TelaFormasPagamento({super.key});

  @override
  State<TelaFormasPagamento> createState() => _TelaFormasPagamentoState();
}

class _TelaFormasPagamentoState extends State<TelaFormasPagamento> {
  List<Map<String, dynamic>> _formas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final response = await ApiService.dio.get('/formas-pagamento');
      final dados = response.data as List;
      setState(() {
        _formas = dados
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _abrirDialogNova() async {
    final criada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogForma(titulo: 'Nova forma de pagamento'),
    );
    if (criada == true) _carregar();
  }

  Future<void> _abrirDialogEditar(Map<String, dynamic> forma) async {
    final editada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogForma(
        titulo: 'Editar forma de pagamento',
        forma: forma,
      ),
    );
    if (editada == true) _carregar();
  }

  Future<void> _toggleAtivo(Map<String, dynamic> forma) async {
    final novoAtivo = !(forma['ativo'] as bool? ?? true);
    try {
      await ApiService.dio.put(
        '/formas-pagamento/${forma['id']}',
        data: {'ativo': novoAtivo},
      );
      _carregar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao alterar status. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formas de Pagamento')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogNova,
        tooltip: 'Nova forma de pagamento',
        child: const Icon(Icons.add),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _formas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma forma de pagamento cadastrada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _formas.length,
                  separatorBuilder: (context, i) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final f = _formas[index];
                    final ativo = f['ativo'] as bool? ?? true;
                    final posterior =
                        f['pagamento_posterior'] as bool? ?? false;
                    final contaPosterior =
                        f['conta_posterior'] as bool? ?? false;
                    final parceladoEmAte = f['parcelado_em_ate'] as int? ?? 1;
                    final partes = <String>[];
                    if (posterior) {
                      partes.add('Crediário');
                    } else if (contaPosterior) {
                      partes.add('Conta definida depois');
                    }
                    if (parceladoEmAte > 1) {
                      partes.add('Parcela em até ${parceladoEmAte}x');
                    }
                    final legenda = partes.isEmpty ? null : partes.join(' · ');

                    return ListTile(
                      leading: Icon(
                        Icons.payment,
                        color: ativo ? Colors.green[700] : Colors.grey,
                      ),
                      title: Text(
                        f['nome'] as String? ?? '',
                        style: TextStyle(
                          color: ativo ? null : Colors.grey,
                          decoration: ativo
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: legenda != null
                          ? Text(
                              legenda,
                              style: TextStyle(
                                  color: Colors.orange[700], fontSize: 12),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: ativo ? 'Desativar' : 'Ativar',
                            child: Switch(
                              value: ativo,
                              onChanged: (_) => _toggleAtivo(f),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () => _abrirDialogEditar(f),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Dialog de criar/editar ──────────────────────────────────────────────────

class _DialogForma extends StatefulWidget {
  final String titulo;
  final Map<String, dynamic>? forma;

  const _DialogForma({required this.titulo, this.forma});

  @override
  State<_DialogForma> createState() => _DialogFormaState();
}

class _DialogFormaState extends State<_DialogForma> {
  final _nomeController = TextEditingController();
  final _parceladoController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  bool _posterior = false;
  bool _contaPosterior = false;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.forma != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _nomeController.text = widget.forma!['nome'] as String? ?? '';
      _posterior = widget.forma!['pagamento_posterior'] as bool? ?? false;
      _contaPosterior = widget.forma!['conta_posterior'] as bool? ?? false;
      _parceladoController.text =
          (widget.forma!['parcelado_em_ate'] as int? ?? 1).toString();
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _parceladoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final body = {
        'nome': _nomeController.text.trim(),
        'pagamento_posterior': _posterior,
        'conta_posterior': _contaPosterior,
        'parcelado_em_ate':
            (int.tryParse(_parceladoController.text.trim()) ?? 1).clamp(1, 99),
      };
      if (_editando) {
        await ApiService.dio
            .put('/formas-pagamento/${widget.forma!['id']}', data: body);
      } else {
        await ApiService.dio.post('/formas-pagamento', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() {
        _erro = 'Erro ao salvar. Tente novamente.';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nomeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _parceladoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Parcelar em até (vezes)',
                helperText: '1 = à vista. Acima de 1 libera a escolha de '
                    'parcelas no pagamento (ex.: crédito 6x).',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) return 'Informe um número ≥ 1';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Crediário (pagamento posterior)'),
              subtitle: const Text(
                'Marcado como "a receber" — não conta como pago.',
                style: TextStyle(fontSize: 12),
              ),
              value: _posterior,
              onChanged: (v) => setState(() {
                _posterior = v;
                if (v) _contaPosterior = false; // mutuamente exclusivos
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conta definida depois'),
              subtitle: const Text(
                'Sem conta no PDV (ex: Dinheiro, Cheque) — fica pendente até ser '
                'colocado numa conta na consulta.',
                style: TextStyle(fontSize: 12),
              ),
              value: _contaPosterior,
              onChanged: (v) => setState(() {
                _contaPosterior = v;
                if (v) _posterior = false; // mutuamente exclusivos
              }),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erro!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
