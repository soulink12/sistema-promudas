import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/api_service.dart';

/// Modal de entrega — cria uma nova entrega ou edita uma existente.
/// Quando [retiradaParaEditar] é informado, entra em modo de edição:
/// pré-preenche os campos e usa PUT /retiradas/:id.
class ModalRetirada extends StatefulWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback onSalvo;
  final Map<String, dynamic>? retiradaParaEditar;

  const ModalRetirada({
    super.key,
    required this.pedido,
    required this.onSalvo,
    this.retiradaParaEditar,
  });

  @override
  State<ModalRetirada> createState() => _ModalRetiradaState();
}

class _ModalRetiradaState extends State<ModalRetirada> {
  // TODO: criar tabela locais_saida e endpoint GET /api/locais-saida para tornar configurável
  static const _locaisSaida = ['Paraíso', 'BR', 'Doze'];

  String? _localSaida;
  DateTime _dataRetirada = DateTime.now();
  final _motoristaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  bool _salvando = false;

  late final List<Map<String, dynamic>> _itensComSaldo;
  late final List<TextEditingController> _qtdControllers;

  bool get _modoEdicao => widget.retiradaParaEditar != null;

  @override
  void initState() {
    super.initState();
    _itensComSaldo = _calcularItensComSaldo();
    _qtdControllers = _itensComSaldo
        .map((item) => TextEditingController(
              text: (item['qtd_atual'] as int? ?? 0).toString(),
            ))
        .toList();

    // Pré-preenche os campos quando está editando
    final retirada = widget.retiradaParaEditar;
    if (retirada != null) {
      final local = retirada['local_saida'] as String?;
      if (local != null && _locaisSaida.contains(local)) _localSaida = local;

      final dataIso = retirada['data_retirada'];
      final data = DateTime.tryParse(dataIso?.toString() ?? '')?.toLocal();
      if (data != null) _dataRetirada = data;

      _motoristaCtrl.text = retirada['motorista'] as String? ?? '';
      _placaCtrl.text = retirada['placa_veiculo'] as String? ?? '';
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

  List<Map<String, dynamic>> _calcularItensComSaldo() {
    final itens = (widget.pedido['itens_pedido'] as List?)
            ?.map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList() ??
        [];

    final retiradas = (widget.pedido['retiradas'] as List?) ?? [];
    final idEditando = widget.retiradaParaEditar?['id'] as int?;

    // Acumula total já retirado por produto_id em OUTRAS retiradas
    // (em modo edição, ignora a própria retirada sendo editada).
    final Map<int, int> totalRetirado = {};
    // Quantidade que a retirada em edição já possui por produto_id.
    final Map<int, int> qtdAtualEdicao = {};

    for (final ret in retiradas) {
      final ehRetiradaEditada =
          idEditando != null && (ret['id'] as int?) == idEditando;
      final itensRet = (ret['itens_retirada'] as List?) ?? [];
      for (final ir in itensRet) {
        final prodId = ir['produto_id'] as int;
        final qtd = ir['quantidade'] as int;
        if (ehRetiradaEditada) {
          qtdAtualEdicao[prodId] = (qtdAtualEdicao[prodId] ?? 0) + qtd;
        } else {
          totalRetirado[prodId] = (totalRetirado[prodId] ?? 0) + qtd;
        }
      }
    }

    return itens
        .map((item) {
          final prodId = item['produto_id'] as int;
          final qtdPedida = item['quantidade'] as int;
          final jaRetirado = totalRetirado[prodId] ?? 0;
          return {
            ...item,
            // Saldo disponível para esta retirada (exclui a própria, se editando)
            'saldo': qtdPedida - jaRetirado,
            'ja_retirado': jaRetirado,
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
        final id = widget.retiradaParaEditar!['id'];
        // Em edição enviamos motorista/placa sempre (mesmo vazios) para permitir limpar
        await ApiService.dio.put('/retiradas/$id', data: {
          'local_saida': _localSaida,
          'data_retirada': _dataRetirada.toUtc().toIso8601String(),
          'motorista': _motoristaCtrl.text.trim(),
          'placa_veiculo': _placaCtrl.text.trim(),
          'itens': itens,
        });
      } else {
        await ApiService.dio.post('/retiradas', data: {
          'pedido_id': widget.pedido['id'],
          'local_saida': _localSaida,
          'data_retirada': _dataRetirada.toUtc().toIso8601String(),
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

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataRetirada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data != null) setState(() => _dataRetirada = data);
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
              _Secao(label: 'ITENS A RETIRAR'),
              const SizedBox(height: 10),
              ..._itensComSaldo.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final nomeProduto =
                    (item['produtos'] as Map?)?['nome'] as String? ?? '—';
                final saldo = item['saldo'] as int;
                final jaRetirado = item['ja_retirado'] as int;
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
                              'Pedido: $qtdPedida  ·  Retirado: $jaRetirado  ·  Saldo: $saldo',
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

              // ── Local de saída (obrigatório) ───────────────────────────
              _Secao(label: 'LOCAL DE SAÍDA *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _localSaida,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Selecionar local',
                ),
                items: _locaisSaida
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _localSaida = v),
              ),
              const SizedBox(height: 16),

              // ── Data da retirada ───────────────────────────────────────
              _Secao(label: 'DATA DA RETIRADA'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selecionarData,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_formatarData(_dataRetirada)),
                ),
              ),
              const SizedBox(height: 16),

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
