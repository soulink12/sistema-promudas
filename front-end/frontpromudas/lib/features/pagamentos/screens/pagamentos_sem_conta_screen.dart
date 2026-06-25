import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/conta_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/formatadores.dart';

/// Consulta dos pagamentos que ainda não foram colocados em uma conta.
/// Ex: pagamentos em dinheiro (e futuramente cheque) registrados no PDV sem
/// conta definida — ficam "sem conta" até serem atribuídos a uma conta aqui.
class TelaPagamentosSemConta extends StatefulWidget {
  const TelaPagamentosSemConta({super.key});

  @override
  State<TelaPagamentosSemConta> createState() => _TelaPagamentosSemContaState();
}

class _TelaPagamentosSemContaState extends State<TelaPagamentosSemConta> {
  List<Map<String, dynamic>> _pagamentos = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final response = await ApiService.dio.get('/pagamentos/pendentes-conta');
      final lista = (response.data as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _pagamentos = lista;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar pagamentos. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    }
  }

  Future<void> _definirConta(Map<String, dynamic> pagamento) async {
    final conta = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogDefinirConta(),
    );
    if (conta == null) return;

    try {
      await ApiService.dio.put(
        '/pagamentos/${pagamento['id']}',
        data: {'conta': conta},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pagamento colocado na conta "$conta".'),
          backgroundColor: CoresSemanticas.sucesso,
        ),
      );
      _carregar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao definir a conta. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos sem conta')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _pagamentos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum pagamento sem conta.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pagamentos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CardPagamentoSemConta(
                      pagamento: _pagamentos[i],
                      onDefinirConta: () => _definirConta(_pagamentos[i]),
                    ),
                  ),
                ),
    );
  }
}

// ── Card de um pagamento sem conta ──────────────────────────────────────────

class _CardPagamentoSemConta extends StatelessWidget {
  final Map<String, dynamic> pagamento;
  final VoidCallback onDefinirConta;

  const _CardPagamentoSemConta({
    required this.pagamento,
    required this.onDefinirConta,
  });

  String _formatarData(dynamic iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pedido = pagamento['pedidos'] as Map<String, dynamic>?;
    final numeroPedido = pedido != null ? formatarNumeroPedido(pedido) : '—';
    final cliente =
        (pedido?['clientes'] as Map<String, dynamic>?)?['nome'] as String? ??
            '—';
    final forma = pagamento['forma_pagamento'] as String? ?? '—';
    final data = _formatarData(pagamento['criado_em']);
    final valor = _toDouble(pagamento['valor_pago']);

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
                      Text(
                        cliente,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pedido $numeroPedido · $data',
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        forma,
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatarMoeda(valor),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary),
                    ),
                    const SizedBox(height: 6),
                    _PillSemConta(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDefinirConta,
                icon: const Icon(Icons.account_balance_wallet_outlined,
                    size: 18),
                label: const Text('Definir conta'),
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

class _PillSemConta extends StatelessWidget {
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
      child: Text(
        'Sem conta',
        style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Dialog para escolher a conta ────────────────────────────────────────────

class _DialogDefinirConta extends StatefulWidget {
  const _DialogDefinirConta();

  @override
  State<_DialogDefinirConta> createState() => _DialogDefinirContaState();
}

class _DialogDefinirContaState extends State<_DialogDefinirConta> {
  List<String> _contas = [];
  String? _selecionada;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final contas = await ContaService().listar();
      setState(() {
        _contas = contas;
        _selecionada = contas.isNotEmpty ? contas.first : null;
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar as contas.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Definir conta'),
      content: SizedBox(
        width: 360,
        child: _carregando
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _erro != null
                ? Text(_erro!)
                : DropdownButtonFormField<String>(
                    value: _selecionada,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Conta',
                      border: OutlineInputBorder(),
                    ),
                    items: _contas
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selecionada = v),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_carregando || _selecionada == null)
              ? null
              : () => Navigator.pop(context, _selecionada),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
