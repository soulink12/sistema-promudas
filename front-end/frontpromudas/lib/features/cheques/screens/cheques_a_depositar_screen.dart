import 'package:flutter/material.dart';
import '../../../core/services/cheque_service.dart';
import '../../../core/services/conta_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/api_feedback.dart';
import '../../../core/utils/formatadores.dart';

/// Lista os cheques que ainda precisam ser depositados (data de depósito vazia).
/// Ao registrar o depósito, o cheque sai da lista e a data do depósito vira a
/// data efetiva daquele pagamento.
class TelaChequesADepositar extends StatefulWidget {
  const TelaChequesADepositar({super.key});

  @override
  State<TelaChequesADepositar> createState() => _TelaChequesADepositarState();
}

class _TelaChequesADepositarState extends State<TelaChequesADepositar> {
  final _service = ChequeService();
  List<Map<String, dynamic>> _cheques = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await _service.listarADepositar();
      setState(() {
        _cheques = lista;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao carregar os cheques.'));
    }
  }

  Future<void> _registrarDeposito(Map<String, dynamic> cheque) async {
    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogDeposito(cheque: cheque),
    );
    if (dados == null) return;
    try {
      await _service.registrarDeposito(cheque['id'] as int, dados);
      if (!mounted) return;
      mostrarSucesso(context, 'Depósito registrado.');
      _carregar();
    } catch (e) {
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao registrar o depósito.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cheques a depositar')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _cheques.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('Nenhum cheque a depositar.',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cheques.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CardCheque(
                      cheque: _cheques[i],
                      onDepositar: () => _registrarDeposito(_cheques[i]),
                    ),
                  ),
                ),
    );
  }
}

// ── Card de um cheque a depositar ───────────────────────────────────────────

class _CardCheque extends StatelessWidget {
  final Map<String, dynamic> cheque;
  final VoidCallback onDepositar;

  const _CardCheque({required this.cheque, required this.onDepositar});

  double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

  String? _data(dynamic iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return null;
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pagamento = cheque['pagamentos'] as Map<String, dynamic>?;
    final pedido = pagamento?['pedidos'] as Map<String, dynamic>?;
    final numeroPedido = pedido != null ? formatarNumeroPedido(pedido) : '—';
    final cliente =
        (pedido?['clientes'] as Map<String, dynamic>?)?['nome'] as String? ??
            '—';
    final numero = cheque['numero'] as String?;
    final banco = cheque['banco'] as String?;
    final bomPara = _data(cheque['bom_para']);
    final valor = _toDouble(cheque['valor']);

    final detalhe = <String>[
      if (numero != null && numero.isNotEmpty) 'nº $numero',
      if (banco != null && banco.isNotEmpty) banco,
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Pedido $numeroPedido',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                      if (detalhe.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Cheque $detalhe',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                      ],
                      if (bomPara != null) ...[
                        const SizedBox(height: 2),
                        Text('Bom para: $bomPara',
                            style: const TextStyle(
                                color: CoresSemanticas.aviso, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatarMoeda(valor),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cs.primary)),
                    const SizedBox(height: 6),
                    _PillADepositar(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDepositar,
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: const Text('Registrar depósito'),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillADepositar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const cor = CoresSemanticas.aviso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text('A depositar',
          style: TextStyle(
              color: cor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Dialog de registrar depósito ────────────────────────────────────────────

class _DialogDeposito extends StatefulWidget {
  final Map<String, dynamic> cheque;
  const _DialogDeposito({required this.cheque});

  @override
  State<_DialogDeposito> createState() => _DialogDepositoState();
}

class _DialogDepositoState extends State<_DialogDeposito> {
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _bancoCtrl;
  late final TextEditingController _agenciaCtrl;
  late final TextEditingController _contaCtrl;
  DateTime _dataDeposito = DateTime.now();
  // Conta de destino (para onde o valor entra) — preenche `pagamentos.conta`.
  List<String> _contas = [];
  String? _contaSelecionada;

  @override
  void initState() {
    super.initState();
    final c = widget.cheque;
    _numeroCtrl = TextEditingController(text: c['numero'] as String? ?? '');
    _bancoCtrl = TextEditingController(text: c['banco'] as String? ?? '');
    _agenciaCtrl = TextEditingController(text: c['agencia'] as String? ?? '');
    _contaCtrl =
        TextEditingController(text: c['conta_corrente'] as String? ?? '');
    _carregarContas();
  }

  Future<void> _carregarContas() async {
    try {
      final contas = await ContaService().listar();
      if (mounted) {
        setState(() {
          _contas = contas;
          _contaSelecionada = contas.isNotEmpty ? contas.first : null;
        });
      }
    } catch (_) {
      // Falha silenciosa — depósito ainda pode ser registrado sem conta.
    }
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _bancoCtrl.dispose();
    _agenciaCtrl.dispose();
    _contaCtrl.dispose();
    super.dispose();
  }

  String? _ouNulo(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhido = await showDatePicker(
      context: context,
      initialDate: _dataDeposito,
      firstDate: DateTime(hoje.year - 2),
      lastDate: DateTime(hoje.year + 1),
    );
    if (escolhido != null) setState(() => _dataDeposito = escolhido);
  }

  void _confirmar() {
    Navigator.pop(context, <String, dynamic>{
      // Meio-dia para não deslocar o dia ao converter para UTC.
      'data_deposito': DateTime(_dataDeposito.year, _dataDeposito.month,
              _dataDeposito.day, 12)
          .toUtc()
          .toIso8601String(),
      'numero': _ouNulo(_numeroCtrl.text),
      'banco': _ouNulo(_bancoCtrl.text),
      'agencia': _ouNulo(_agenciaCtrl.text),
      'conta_corrente': _ouNulo(_contaCtrl.text),
      if (_contaSelecionada != null) 'conta': _contaSelecionada,
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataTexto = '${_dataDeposito.day.toString().padLeft(2, '0')}/'
        '${_dataDeposito.month.toString().padLeft(2, '0')}/${_dataDeposito.year}';
    return AlertDialog(
      title: const Text('Registrar depósito'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Data do depósito'),
              subtitle: Text(dataTexto),
              trailing: TextButton(
                onPressed: _escolherData,
                child: const Text('Alterar'),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numeroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nº do cheque',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bancoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Banco',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _agenciaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Agência',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _contaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Conta corrente',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _contaSelecionada,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Conta de destino',
                helperText: 'Para onde o valor entra ao depositar.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _contas
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _contaSelecionada = v),
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
          onPressed: _confirmar,
          child: const Text('Confirmar depósito'),
        ),
      ],
    );
  }
}
