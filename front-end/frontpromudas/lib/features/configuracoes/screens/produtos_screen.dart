import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/formatadores.dart';

class TelaProdutos extends StatefulWidget {
  const TelaProdutos({super.key});

  @override
  State<TelaProdutos> createState() => _TelaProdutosState();
}

class _TelaProdutosState extends State<TelaProdutos> {
  List<Map<String, dynamic>> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final response = await ApiService.dio.get('/produtos');
      final dados = response.data as List;
      setState(() {
        _produtos = dados
            .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _abrirDialogNovo() async {
    final criado = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogProduto(titulo: 'Novo produto'),
    );
    if (criado == true) _carregar();
  }

  Future<void> _abrirDialogEditar(Map<String, dynamic> produto) async {
    final editado = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DialogProduto(titulo: 'Editar produto', produto: produto),
    );
    if (editado == true) _carregar();
  }

  Future<void> _toggleAtivo(Map<String, dynamic> produto) async {
    final novoAtivo = !(produto['ativo'] as bool? ?? true);
    try {
      await ApiService.dio.put(
        '/produtos/${produto['id']}',
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
      appBar: AppBar(title: const Text('Produtos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogNovo,
        tooltip: 'Novo produto',
        child: const Icon(Icons.add),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _produtos.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum produto cadastrado.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: _produtos.length,
                  separatorBuilder: (context, i) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = _produtos[index];
                    final ativo = p['ativo'] as bool? ?? true;
                    final preco =
                        double.tryParse(p['preco'].toString()) ?? 0.0;
                    final cs = Theme.of(context).colorScheme;

                    return ListTile(
                      leading: Icon(
                        Icons.eco_outlined,
                        color: ativo ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        p['nome'] as String? ?? '',
                        style: TextStyle(
                          color: ativo ? null : cs.onSurfaceVariant,
                          decoration:
                              ativo ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        formatarMoeda(preco),
                        style: TextStyle(
                          color: ativo ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: ativo ? 'Desativar' : 'Ativar',
                            child: Switch(
                              value: ativo,
                              onChanged: (_) => _toggleAtivo(p),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () => _abrirDialogEditar(p),
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

class _DialogProduto extends StatefulWidget {
  final String titulo;
  final Map<String, dynamic>? produto;

  const _DialogProduto({required this.titulo, this.produto});

  @override
  State<_DialogProduto> createState() => _DialogProdutoState();
}

class _DialogProdutoState extends State<_DialogProduto> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _precoController = TextEditingController();
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.produto != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _nomeController.text = widget.produto!['nome'] as String? ?? '';
      final preco =
          double.tryParse(widget.produto!['preco'].toString()) ?? 0.0;
      _precoController.text = preco.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final preco = double.parse(
          _precoController.text.trim().replaceAll(',', '.'));
      final body = {
        'nome': _nomeController.text.trim(),
        'preco': preco,
      };
      if (_editando) {
        await ApiService.dio
            .put('/produtos/${widget.produto!['id']}', data: body);
      } else {
        await ApiService.dio.post('/produtos', data: body);
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
          children: [
            TextFormField(
              controller: _nomeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Campo obrigatório'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preço *',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                final valor =
                    double.tryParse(v.trim().replaceAll(',', '.'));
                if (valor == null || valor < 0) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_erro!,
                    style: const TextStyle(
                        color: CoresSemanticas.erro, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _salvando ? null : () => Navigator.pop(context, false),
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
