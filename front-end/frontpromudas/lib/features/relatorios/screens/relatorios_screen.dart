import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class TelaRelatorios extends StatefulWidget {
  const TelaRelatorios({super.key});

  @override
  State<TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends State<TelaRelatorios> {
  DateTime? _de;
  DateTime? _ate;
  String? _formaSelecionada;
  List<String> _formasDisponiveis = [];

  List<Map<String, dynamic>>? _resultado;
  double _totalGeral = 0;
  bool _carregando = false;
  bool _carregandoFormas = true;

  @override
  void initState() {
    super.initState();
    _carregarFormas();
  }

  Future<void> _carregarFormas() async {
    try {
      final response = await ApiService.dio.get('/formas-pagamento');
      final dados = response.data as List;
      setState(() {
        _formasDisponiveis = dados
            .where((f) => f['ativo'] as bool? ?? true)
            .map<String>((f) => f['nome'] as String)
            .toList();
        _carregandoFormas = false;
      });
    } catch (_) {
      setState(() => _carregandoFormas = false);
    }
  }

  Future<void> _gerarRelatorio() async {
    setState(() {
      _carregando = true;
      _resultado = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_de != null) params['de'] = _de!.toIso8601String();
      if (_ate != null) {
        // inclui o dia inteiro da data final
        final ateFinaldoDia =
            DateTime(_ate!.year, _ate!.month, _ate!.day, 23, 59, 59);
        params['ate'] = ateFinaldoDia.toIso8601String();
      }
      if (_formaSelecionada != null) params['forma'] = _formaSelecionada;

      final response = await ApiService.dio.get(
        '/relatorios/pagamentos',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final lista = (data['resultado'] as List)
          .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _resultado = lista;
        _totalGeral =
            double.tryParse(data['totalGeral'].toString()) ?? 0.0;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar relatório. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selecionarData(bool isDe) async {
    final inicial = isDe ? (_de ?? DateTime.now()) : (_ate ?? DateTime.now());
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;
    setState(() {
      if (isDe) {
        _de = data;
        if (_ate != null && _ate!.isBefore(_de!)) _ate = null;
      } else {
        _ate = data;
        if (_de != null && _de!.isAfter(_ate!)) _de = null;
      }
    });
  }

  String _formatarData(DateTime? dt) {
    if (dt == null) return 'Selecionar';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Painel de filtros ───────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FILTROS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BotaoData(
                          label: 'De',
                          valor: _formatarData(_de),
                          selecionado: _de != null,
                          onTap: () => _selecionarData(true),
                          onLimpar: _de != null
                              ? () => setState(() => _de = null)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BotaoData(
                          label: 'Até',
                          valor: _formatarData(_ate),
                          selecionado: _ate != null,
                          onTap: () => _selecionarData(false),
                          onLimpar: _ate != null
                              ? () => setState(() => _ate = null)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _carregandoFormas
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<String?>(
                          initialValue: _formaSelecionada,
                          decoration: const InputDecoration(
                            labelText: 'Forma de pagamento',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todas as formas'),
                            ),
                            ..._formasDisponiveis.map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(f),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _formaSelecionada = v),
                        ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _carregando ? null : _gerarRelatorio,
                      icon: _carregando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bar_chart),
                      label: const Text('Gerar Relatório'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Resultados ─────────────────────────────────────────────────
          if (_resultado != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                color: Colors.green[700],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL GERAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'R\$ ${_totalGeral.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_resultado!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhum pagamento encontrado para os filtros selecionados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _resultado!.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = _resultado![index];
                    final total =
                        double.tryParse(r['total'].toString()) ?? 0.0;
                    final quantidade = r['quantidade'] as int? ?? 0;
                    final forma =
                        r['forma_pagamento'] as String? ?? '—';
                    final percentual = _totalGeral > 0
                        ? (total / _totalGeral)
                        : 0.0;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  forma,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'R\$ ${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$quantidade pagamento${quantidade != 1 ? 's' : ''}',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12),
                                ),
                                Text(
                                  '${(percentual * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentual.toDouble(),
                                minHeight: 6,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green[400]!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Widget auxiliar: botão de data ──────────────────────────────────────────

class _BotaoData extends StatelessWidget {
  final String label;
  final String valor;
  final bool selecionado;
  final VoidCallback onTap;
  final VoidCallback? onLimpar;

  const _BotaoData({
    required this.label,
    required this.valor,
    required this.selecionado,
    required this.onTap,
    this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(
          color: selecionado ? Colors.green : Colors.grey.shade400,
        ),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: selecionado ? Colors.green[700] : Colors.grey,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 13,
                    color: selecionado ? Colors.green[800] : Colors.grey,
                    fontWeight: selecionado
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onLimpar != null)
            GestureDetector(
              onTap: onLimpar,
              child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}
