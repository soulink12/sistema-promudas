import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/produto_service.dart';
import '../../../../core/utils/api_feedback.dart';
import '../../../../core/utils/formatadores.dart';
import '../../../../core/widgets/campo_busca_cliente.dart';

/// Modal para cadastrar ou editar um interessado: cliente + lista de mudas de
/// interesse (só produto + quantidade, sem valor — diferente de pedido/orçamento).
/// Quando [interessadoParaEditar] é informado, entra em modo de edição e usa
/// PUT /interessados/:id; senão cria via POST /interessados.
class ModalInteressado extends StatefulWidget {
  final Map<String, dynamic>? interessadoParaEditar;
  final VoidCallback onSalvo;

  const ModalInteressado({
    super.key,
    this.interessadoParaEditar,
    required this.onSalvo,
  });

  @override
  State<ModalInteressado> createState() => _ModalInteressadoState();
}

class _ModalInteressadoState extends State<ModalInteressado> {
  Map<String, dynamic>? _cliente;
  final List<Map<String, dynamic>> _itens = []; // {produto_id, nome, quantidade}

  List<Map<String, dynamic>> _produtos = [];
  bool _carregandoProdutos = true;
  Map<String, dynamic>? _produtoParaAdicionar;
  final _qtdParaAdicionarCtrl = TextEditingController(text: '1');

  bool _salvando = false;

  bool get _modoEdicao => widget.interessadoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final editar = widget.interessadoParaEditar;
    if (editar != null) {
      final clienteMap = editar['clientes'] as Map?;
      if (clienteMap != null) _cliente = Map<String, dynamic>.from(clienteMap);
      final itens = (editar['itens_interesse'] as List? ?? []);
      for (final e in itens) {
        final item = Map<String, dynamic>.from(e as Map);
        final produtoId = item['produto_id'] as int;
        _itens.add({
          'produto_id': produtoId,
          'nome': (item['produtos'] as Map?)?['nome'] as String? ?? 'Produto #$produtoId',
          'quantidade': item['quantidade'] as int,
        });
      }
    }
    _carregarProdutos();
  }

  @override
  void dispose() {
    _qtdParaAdicionarCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    try {
      final produtos = await ProdutoService().listar();
      if (mounted) setState(() { _produtos = produtos; _carregandoProdutos = false; });
    } catch (_) {
      if (mounted) setState(() => _carregandoProdutos = false);
    }
  }

  void _adicionarItem() {
    final produto = _produtoParaAdicionar;
    if (produto == null) return;
    final qtd = int.tryParse(_qtdParaAdicionarCtrl.text.trim()) ?? 0;
    if (qtd <= 0) return;

    setState(() {
      final idx = _itens.indexWhere((i) => i['produto_id'] == produto['id']);
      if (idx != -1) {
        _itens[idx]['quantidade'] = (_itens[idx]['quantidade'] as int) + qtd;
      } else {
        _itens.add({
          'produto_id': produto['id'],
          'nome': produto['nome'],
          'quantidade': qtd,
        });
      }
      _produtoParaAdicionar = null;
      _qtdParaAdicionarCtrl.text = '1';
    });
  }

  void _removerItem(int index) => setState(() => _itens.removeAt(index));

  bool get _podeSalvar => _cliente != null && _itens.isNotEmpty && !_salvando;

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final dados = {
      'cliente_id': _cliente!['id'],
      'itens': _itens
          .map((i) => {'produto_id': i['produto_id'], 'quantidade': i['quantidade']})
          .toList(),
    };
    try {
      if (_modoEdicao) {
        await ApiService.dio.put('/interessados/${widget.interessadoParaEditar!['id']}', data: dados);
      } else {
        await ApiService.dio.post('/interessados', data: dados);
      }
      widget.onSalvo();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _salvando = false);
      final acao = _modoEdicao ? 'atualizar' : 'registrar';
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao $acao interessado.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_modoEdicao ? 'Editar Interessado' : 'Novo Interessado'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Secao(label: 'CLIENTE *'),
              const SizedBox(height: 8),
              _cliente == null
                  ? CampoBuscaCliente(
                      hintText: 'Digite nome, CPF ou telefone',
                      onSelecionado: (c) => setState(() => _cliente = c),
                    )
                  : Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Icon(Icons.person_outline, color: cs.primary),
                        title: Text(
                          capitalizarNome(_cliente!['nome'] as String? ?? ''),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Trocar cliente',
                          onPressed: () => setState(() => _cliente = null),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),

              _Secao(label: 'MUDAS DE INTERESSE *'),
              const SizedBox(height: 8),
              if (_carregandoProdutos)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: _produtoParaAdicionar,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Muda',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _produtos
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p['nome'] as String, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (p) => setState(() => _produtoParaAdicionar = p),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _qtdParaAdicionarCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Qtd.',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: cs.primary),
                      tooltip: 'Adicionar muda',
                      onPressed: _produtoParaAdicionar == null ? null : _adicionarItem,
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              if (_itens.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nenhuma muda adicionada ainda.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _itens.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _itens[index];
                        return ListTile(
                          dense: true,
                          title: Text(item['nome'] as String),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('qtd. ${item['quantidade']}'),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: cs.error),
                                tooltip: 'Remover',
                                onPressed: () => _removerItem(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _podeSalvar ? _salvar : null,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_modoEdicao ? 'Salvar Alterações' : 'Salvar'),
        ),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  final String label;
  const _Secao({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}
