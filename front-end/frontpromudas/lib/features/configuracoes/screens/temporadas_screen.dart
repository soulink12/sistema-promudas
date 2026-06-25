import 'package:flutter/material.dart';
import '../../../core/services/temporada_service.dart';
import '../../../core/utils/api_feedback.dart';

/// Gerencia as temporadas (safras) do sistema. A temporada ativa define a
/// numeração dos novos pedidos (26-1, 26-2…). Exclusiva da Administração.
class TelaTemporadas extends StatefulWidget {
  const TelaTemporadas({super.key});

  @override
  State<TelaTemporadas> createState() => _TelaTemporadasState();
}

class _TelaTemporadasState extends State<TelaTemporadas> {
  final _service = TemporadaService();
  List<Map<String, dynamic>> _temporadas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await _service.listar();
      if (!mounted) return;
      setState(() {
        _temporadas = lista;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  Future<void> _ativar(Map<String, dynamic> t) async {
    if (t['ativo'] == true) return;
    try {
      await _service.ativar(t['id'] as int);
      await _carregar();
      if (mounted) {
        mostrarSucesso(context, 'Temporada ${t['ano']} ativada.');
      }
    } catch (e) {
      if (mounted) mostrarErro(context, extrairErroApi(e));
    }
  }

  Future<void> _abrirDialogNova() async {
    final criada = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogNovaTemporada(),
    );
    if (criada == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Temporadas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogNova,
        tooltip: 'Nova temporada',
        child: const Icon(Icons.add),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _temporadas.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma temporada cadastrada.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'A temporada ativa numera os novos pedidos (ex.: 26-1, '
                        '26-2). Ao trocar de temporada, a contagem reinicia.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _temporadas.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = _temporadas[index];
                          final ativo = t['ativo'] as bool? ?? false;
                          final ano = t['ano'] as int;
                          final aa = (ano % 100).toString().padLeft(2, '0');
                          return ListTile(
                            leading: Icon(
                              Icons.calendar_today_outlined,
                              color:
                                  ativo ? cs.primary : cs.onSurfaceVariant,
                            ),
                            title: Text(
                              '$ano',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Pedidos: $aa-1, $aa-2…',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                            trailing: ativo
                                ? Chip(
                                    label: const Text('Ativa'),
                                    backgroundColor: cs.primary.withAlpha(30),
                                    side: BorderSide(
                                        color: cs.primary.withAlpha(80)),
                                    visualDensity: VisualDensity.compact,
                                  )
                                : TextButton(
                                    onPressed: () => _ativar(t),
                                    child: const Text('Ativar'),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Dialog de nova temporada ────────────────────────────────────────────────

class _DialogNovaTemporada extends StatefulWidget {
  const _DialogNovaTemporada();

  @override
  State<_DialogNovaTemporada> createState() => _DialogNovaTemporadaState();
}

class _DialogNovaTemporadaState extends State<_DialogNovaTemporada> {
  final _service = TemporadaService();
  final _anoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _anoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await _service.criar(int.parse(_anoController.text.trim()));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _erro = extrairErroApi(e, 'Erro ao salvar. Tente novamente.');
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova temporada'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _anoController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ano *',
                hintText: 'Ex.: 2027',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 2000 || n > 2100) {
                  return 'Informe um ano válido (2000–2100)';
                }
                return null;
              },
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
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
