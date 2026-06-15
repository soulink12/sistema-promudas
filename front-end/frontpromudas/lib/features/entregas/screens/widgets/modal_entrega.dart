import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/local_entrega_service.dart';
import '../../../../core/widgets/seletor_data_hora.dart';

/// Modal de entrega — cria uma nova entrega ou edita uma existente.
/// Quando [entregaParaEditar] é informado, entra em modo de edição:
/// pré-preenche os campos e usa PUT /entregas/:id.
class ModalEntrega extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback onSalvo;
  final Map<String, dynamic>? entregaParaEditar;

  const ModalEntrega({
    super.key,
    required this.pedido,
    required this.onSalvo,
    this.entregaParaEditar,
  });

  @override
  State<ModalEntrega> createState() => _ModalEntregaState();
}

class _ModalEntregaState extends State<ModalEntrega> {
  // Locais carregados de GET /locais-entrega
  List<String> _locais = [];

  String? _localSaida;
  DateTime _dataEntrega = DateTime.now();
  final _motoristaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  bool _salvando = false;

  late final List<Map<String, dynamic>> _itensComSaldo;
  late final List<TextEditingController> _qtdControllers;

  bool get _modoEdicao => widget.entregaParaEditar != null;

  @override
  void initState() {
    super.initState();
    _carregarLocais();
    _itensComSaldo = _calcularItensComSaldo();
    _qtdControllers = _itensComSaldo
        .map((item) => TextEditingController(
              text: (item['qtd_atual'] as int? ?? 0).toString(),
            ))
        .toList();

    // Pré-preenche os campos quando está editando
    final entrega = widget.entregaParaEditar;
    if (entrega != null) {
      final local = entrega['local_entrega'] as String?;
      if (local != null) _localSaida = local;

      final dataIso = entrega['data_entrega'];
      final data = DateTime.tryParse(dataIso?.toString() ?? '')?.toLocal();
      if (data != null) _dataEntrega = data;

      _motoristaCtrl.text = entrega['motorista'] as String? ?? '';
      _placaCtrl.text = entrega['placa_veiculo'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _motoristaCtrl.dispose();
    _placaCtrl.dispose();
    for (final c in _qtdControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarLocais() async {
    try {
      final locais = await LocalEntregaService().listar();
      if (!mounted) return;
      setState(() {
        _locais = locais;
        // Garante que o local atual (modo edição) esteja na lista de opções
        if (_localSaida != null && !_locais.contains(_localSaida)) {
          _locais = [..._locais, _localSaida!];
        }
      });
    } catch (_) {
      // Em caso de falha, mantém a lista vazia
    }
  }

  List<Map<String, dynamic>> _calcularItensComSaldo() {
    final itens = (widget.pedido['itens_pedido'] as List?)
            ?.map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList() ??
        [];

    final entregas = (widget.pedido['entregas'] as List?) ?? [];
    final idEditando = widget.entregaParaEditar?['id'] as int?;

    // Acumula total já entregue por produto_id em OUTRAS entregas
    // (em modo edição, ignora a própria entrega sendo editada).
    final Map<int, int> totalEntregue = {};
    // Quantidade que a entrega em edição já possui por produto_id.
    final Map<int, int> qtdAtualEdicao = {};

    for (final ret in entregas) {
      final ehEntregaEditada =
          idEditando != null && (ret['id'] as int?) == idEditando;
      final itensRet = (ret['itens_entrega'] as List?) ?? [];
      for (final ir in itensRet) {
        final prodId = ir['produto_id'] as int;
        final qtd = ir['quantidade'] as int;
        if (ehEntregaEditada) {
          qtdAtualEdicao[prodId] = (qtdAtualEdicao[prodId] ?? 0) + qtd;
        } else {
          totalEntregue[prodId] = (totalEntregue[prodId] ?? 0) + qtd;
        }
      }
    }

    return itens
        .map((item) {
          final prodId = item['produto_id'] as int;
          final qtdPedida = item['quantidade'] as int;
          final jaEntregue = totalEntregue[prodId] ?? 0;
          return {
            ...item,
            // Saldo disponível para esta entrega (exclui a própria, se editando)
            'saldo': qtdPedida - jaEntregue,
            'ja_entregue': jaEntregue,
            'qtd_atual': qtdAtualEdicao[prodId] ?? 0,
          };
        })
        .where((item) => (item['saldo'] as int) > 0)
        .toList();
  }

  bool get _podeSalvar {
    if (_localSaida == null) return false;
    return _qtdControllers.any((c) => (int.tryParse(c.text) ?? 0) > 0);
  }

  Future<void> _confirmar() async {
    final itens = <Map<String, dynamic>>[];
    for (int i = 0; i < _itensComSaldo.length; i++) {
      final qtd = int.tryParse(_qtdControllers[i].text) ?? 0;
      if (qtd > 0) {
        itens.add({
          'produto_id': _itensComSaldo[i]['produto_id'],
          'quantidade': qtd,
        });
      }
    }

    setState(() => _salvando = true);
    try {
      if (_modoEdicao) {
        final id = widget.entregaParaEditar!['id'];
        // Em edição enviamos motorista/placa sempre (mesmo vazios) para permitir limpar
        await ApiService.dio.put('/entregas/$id', data: {
          'local_entrega': _localSaida,
          'data_entrega': _dataEntrega.toUtc().toIso8601String(),
          'motorista': _motoristaCtrl.text.trim(),
          'placa_veiculo': _placaCtrl.text.trim(),
          'itens': itens,
        });
      } else {
        // Na criação não enviamos a data — o backend grava a data/hora atual
        // (= criado_em). A data pode ser ajustada depois na consulta (edição).
        await ApiService.dio.post('/entregas', data: {
          'pedido_id': widget.pedido['id'],
          'local_entrega': _localSaida,
          if (_motoristaCtrl.text.trim().isNotEmpty)
            'motorista': _motoristaCtrl.text.trim(),
          if (_placaCtrl.text.trim().isNotEmpty)
            'placa_veiculo': _placaCtrl.text.trim(),
          'itens': itens,
        });
      }
      widget.onSalvo();
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_extrairErro(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _extrairErro(Object e) {
    final acao = _modoEdicao ? 'atualizar' : 'registrar';
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) return data['erro'] as String? ?? 'Erro ao $acao entrega.';
    }
    return 'Erro ao $acao entrega.';
  }

  Future<void> _selecionarData() async {
    final nova = await selecionarDataHora(context, _dataEntrega);
    if (nova != null) setState(() => _dataEntrega = nova);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.pedido['id'] as int;
    final clienteMap = widget.pedido['clientes'] as Map<String, dynamic>?;
    final cliente = clienteMap?['nome'] as String? ?? '—';

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_modoEdicao ? 'Editar Entrega' : 'Registrar Entrega'),
          Text(
            '#$id · $cliente',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Itens ──────────────────────────────────────────────────
              _Secao(label: 'ITENS A ENTREGAR'),
              const SizedBox(height: 10),
              ..._itensComSaldo.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final nomeProduto =
                    (item['produtos'] as Map?)?['nome'] as String? ?? '—';
                final saldo = item['saldo'] as int;
                final jaEntregue = item['ja_entregue'] as int;
                final qtdPedida = item['quantidade'] as int;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeProduto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pedido: $qtdPedida  ·  Entregue: $jaEntregue  ·  Saldo: $saldo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtdControllers[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Qtd',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              const SizedBox(height: 12),

              // ── Local de entrega (obrigatório) ─────────────────────────
              _Secao(label: 'LOCAL DE ENTREGA *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _localSaida,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Selecionar local',
                ),
                items: _locais
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _localSaida = v),
              ),
              const SizedBox(height: 16),

              // ── Data da entrega ───────────────────────────────────────
              // Só na edição: na criação a data é a atual (= criado_em).
              if (_modoEdicao) ...[
                _Secao(label: 'DATA/HORA DA ENTREGA'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selecionarData,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon:
                          Icon(Icons.edit_calendar_outlined, size: 18),
                    ),
                    child: Text(formatarDataHora(_dataEntrega)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Veículo (opcional) ─────────────────────────────────────
              _Secao(label: 'VEÍCULO (OPCIONAL)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _motoristaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motorista',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _placaCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Placa',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
          onPressed: (_podeSalvar && !_salvando) ? _confirmar : null,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_modoEdicao ? 'Salvar Alterações' : 'Confirmar Entrega'),
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
