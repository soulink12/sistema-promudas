import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/cores_semanticas.dart';

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
            backgroundColor: CoresSemanticas.erro,
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
              ? Center(
                  child: Text(
                    'Nenhuma forma de pagamento cadastrada.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    final depositoPosterior =
                        f['deposito_posterior'] as bool? ?? false;
                    final escambo = f['escambo'] as bool? ?? false;
                    final parceladoEmAte = f['parcelado_em_ate'] as int? ?? 1;
                    final partes = <String>[];
                    if (posterior) {
                      partes.add('Crediário');
                    } else if (contaPosterior) {
                      partes.add('Conta definida depois');
                    }
                    if (depositoPosterior) {
                      partes.add('Cheque (depósito posterior)');
                    }
                    if (escambo) {
                      partes.add('Escambo (troca)');
                    }
                    if (parceladoEmAte > 1) {
                      partes.add('Parcela em até ${parceladoEmAte}x');
                    }
                    final legenda = partes.isEmpty ? null : partes.join(' · ');
                    final cs = Theme.of(context).colorScheme;

                    return ListTile(
                      leading: Icon(
                        Icons.payment,
                        color: ativo ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        f['nome'] as String? ?? '',
                        style: TextStyle(
                          color: ativo ? null : cs.onSurfaceVariant,
                          decoration: ativo
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: legenda != null
                          ? Text(
                              legenda,
                              style: const TextStyle(
                                  color: CoresSemanticas.aviso, fontSize: 12),
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
  final _valorKgController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _posterior = false;
  bool _contaPosterior = false;
  bool _depositoPosterior = false;
  bool _escambo = false;
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
      _depositoPosterior =
          widget.forma!['deposito_posterior'] as bool? ?? false;
      _escambo = widget.forma!['escambo'] as bool? ?? false;
      _parceladoController.text =
          (widget.forma!['parcelado_em_ate'] as int? ?? 1).toString();
      // Decimal vem do backend como String no JSON — parse robusto.
      final valorKgRaw = widget.forma!['valor_kg_escambo'];
      final valorKg =
          valorKgRaw == null ? null : double.tryParse(valorKgRaw.toString());
      if (valorKg != null) {
        _valorKgController.text = valorKg.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _parceladoController.dispose();
    _valorKgController.dispose();
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
        'deposito_posterior': _depositoPosterior,
        'escambo': _escambo,
        'valor_kg_escambo': _escambo
            ? double.tryParse(_valorKgController.text.trim().replaceAll(',', '.'))
            : null,
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
                if (v) {
                  _contaPosterior = false; // mutuamente exclusivos
                  _depositoPosterior = false;
                  _escambo = false;
                }
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
                if (v) {
                  _posterior = false; // mutuamente exclusivos
                  _escambo = false;
                }
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Depósito posterior (cheque)'),
              subtitle: const Text(
                'Gera cheques a depositar — a data do pagamento é a do depósito, '
                'feito depois na tela de notificações.',
                style: TextStyle(fontSize: 12),
              ),
              value: _depositoPosterior,
              onChanged: (v) => setState(() {
                _depositoPosterior = v;
                if (v) {
                  _posterior = false; // crediário e cheque são exclusivos
                  _escambo = false;
                }
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Escambo (troca por produção)'),
              subtitle: const Text(
                'Pagamento em produção (ex.: pimenta) — o valor é calculado por '
                'kg pela taxa abaixo. Não tem conta.',
                style: TextStyle(fontSize: 12),
              ),
              value: _escambo,
              onChanged: (v) => setState(() {
                _escambo = v;
                if (v) {
                  // Escambo é exclusivo com as demais classificações.
                  _posterior = false;
                  _contaPosterior = false;
                  _depositoPosterior = false;
                }
              }),
            ),
            if (_escambo) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _valorKgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor por kg (R\$) *',
                  helperText: 'Ex.: 3 mudas por kg a R\$ 8,50 = R\$ 25,50/kg.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (!_escambo) return null;
                  final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Informe um valor por kg maior que zero';
                  return null;
                },
              ),
            ],
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erro!,
                    style: const TextStyle(
                        color: CoresSemanticas.erro, fontSize: 13)),
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
