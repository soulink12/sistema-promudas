import 'package:flutter/material.dart';
import '../../../../core/services/forma_pagamento_service.dart';
import '../../../../core/services/conta_service.dart';

/// Modal de registro de pagamento do pedido.
/// Suporta pagamento dividido em múltiplas formas.
///
/// Fluxo:
///   1. Modal abre carregando as formas de pagamento da API
///   2. Operador ajusta valor e pressiona Enter ou clica em "Adicionar"
///   3. Parcela é registrada; campo de valor é pré-preenchido com o restante
///   4. Operador repete até zerar o restante
///   5. Botão "Finalizar Pagamento" fica ativo quando restante ≤ 0
class ModalPagamento extends StatefulWidget {
  final double totalPedido;
  // Callback chamado com a lista de pagamentos ao confirmar
  final Function(List<Map<String, dynamic>> pagamentos) onConfirmar;
  // Quando true, permite finalizar sem cobrir o total (usado na tela de Pedidos)
  final bool parcialPermitido;

  const ModalPagamento({
    super.key,
    required this.totalPedido,
    required this.onConfirmar,
    this.parcialPermitido = false,
  });

  @override
  State<ModalPagamento> createState() => _ModalPagamentoState();
}

class _ModalPagamentoState extends State<ModalPagamento> {
  // Cada parcela: {forma: String, valor: double, pagamentoPosterior: bool}
  final List<Map<String, dynamic>> _pagamentos = [];
  final TextEditingController _valorCtrl = TextEditingController();
  final FocusNode _valorFocusNode = FocusNode();

  // Pagador opcional — usado quando quem paga não é o dono do pedido
  final TextEditingController _nomePagadorCtrl = TextEditingController();
  final TextEditingController _cpfPagadorCtrl = TextEditingController();

  // Lista completa de formas vindas da API
  List<Map<String, dynamic>> _formasPagamento = [];
  // Nome da forma selecionada no dropdown
  String? _formaSelecionada;
  // Contas disponíveis (para onde o pagamento entra) + a selecionada
  List<String> _contas = [];
  String? _contaSelecionada;
  bool _carregando = true;
  String? _erroCarregamento;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final formas = await FormaPagamentoService().listar();
      final contas = await ContaService().listar();
      setState(() {
        _formasPagamento = formas;
        _formaSelecionada = formas.isNotEmpty ? formas.first['nome'] as String : null;
        _contas = contas;
        _contaSelecionada = contas.isNotEmpty ? contas.first : null;
        _valorCtrl.text = widget.totalPedido.toStringAsFixed(2);
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erroCarregamento = 'Não foi possível carregar as formas de pagamento.';
        _carregando = false;
      });
    }
    if (mounted) _valorFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _valorFocusNode.dispose();
    _nomePagadorCtrl.dispose();
    _cpfPagadorCtrl.dispose();
    super.dispose();
  }

  // Retorna true se a forma selecionada é de pagamento posterior (crediário etc.)
  bool get _formaSelecionadaPosterior {
    if (_formaSelecionada == null) return false;
    for (final f in _formasPagamento) {
      if (f['nome'] == _formaSelecionada) {
        return f['pagamentoPosterior'] == true;
      }
    }
    return false;
  }

  // Retorna true se a conta da forma selecionada é definida depois (ex: Dinheiro,
  // Cheque) — nesses casos o pagamento fica com conta pendente, sem escolher no PDV.
  bool get _formaSelecionadaContaPosterior {
    if (_formaSelecionada == null) return false;
    for (final f in _formasPagamento) {
      if (f['nome'] == _formaSelecionada) {
        return f['contaPosterior'] == true;
      }
    }
    return false;
  }

  // Conta não se aplica: crediário (a receber) ou formas de conta definida depois.
  bool get _semContaNoPdv =>
      _formaSelecionadaPosterior || _formaSelecionadaContaPosterior;

  double get _totalPago =>
      _pagamentos.fold(0.0, (s, p) => s + (p['valor'] as double));

  double get _restante => widget.totalPedido - _totalPago;

  // Tolerância para imprecisão de ponto flutuante
  bool get _podeFinalizar => widget.parcialPermitido
      ? _pagamentos.isNotEmpty
      : _restante < 0.005;

  /// Registra a parcela atual e prepara o campo para a próxima entrada.
  void _adicionarPagamento() {
    if (_formaSelecionada == null) return;
    final valor =
        double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) return;

    // Crediário e formas de conta posterior (Dinheiro/Cheque) não escolhem conta
    // aqui — ficam pendentes. As demais exigem conta.
    final posterior = _formaSelecionadaPosterior;
    final semConta = _semContaNoPdv;
    if (!semConta && _contaSelecionada == null) return;

    // Pagador (se informado) é capturado por parcela no momento de adicionar —
    // assim cada pagamento pode ter um pagador diferente. Crediário não tem pagador.
    final nomePagador = _nomePagadorCtrl.text.trim();
    final cpfPagador = _cpfPagadorCtrl.text.trim();

    setState(() {
      _pagamentos.add({
        'forma': _formaSelecionada,
        'valor': valor,
        'pagamentoPosterior': posterior,
        if (!semConta) 'conta': _contaSelecionada,
        if (!posterior && nomePagador.isNotEmpty) 'nomePagador': nomePagador,
        if (!posterior && cpfPagador.isNotEmpty) 'cpfPagador': cpfPagador,
      });
      final restante = _restante;
      _valorCtrl.text =
          restante > 0.005 ? restante.toStringAsFixed(2) : '';
      _nomePagadorCtrl.clear();
      _cpfPagadorCtrl.clear();
    });
    _valorFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final temTroco = _restante < -0.005;
    final valorDestaque = temTroco ? _restante.abs() : _restante;
    final corDestaque = (_podeFinalizar || temTroco)
        ? Colors.green[700]!
        : Colors.orange[800]!;
    final corFundo = (_podeFinalizar || temTroco)
        ? Colors.green[50]!
        : Colors.orange[50]!;
    final corBorda = (_podeFinalizar || temTroco)
        ? Colors.green.shade300
        : Colors.orange.shade300;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: const [
                  Icon(Icons.payments_outlined, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Pagamento do Pedido',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total: R\$ ${widget.totalPedido.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const Divider(height: 24),

              // Parcelas já registradas
              if (_pagamentos.isNotEmpty) ...[
                ..._pagamentos.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final isPosterior = p['pagamentoPosterior'] as bool;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        // Ícone diferente para pagamentos posteriores (crediário)
                        isPosterior
                            ? Icon(Icons.access_time,
                                size: 16, color: Colors.orange[700])
                            : Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['forma'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isPosterior ? Colors.orange[800] : null,
                                ),
                              ),
                              if (p['conta'] != null)
                                Text(
                                  'Conta: ${p['conta']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                )
                              else if (!isPosterior)
                                Text(
                                  'Conta: pendente',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              if (p['nomePagador'] != null)
                                Text(
                                  'Pago por: ${p['nomePagador']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isPosterior)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'a receber',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        Text(
                          'R\$ ${(p['valor'] as double).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isPosterior ? Colors.orange[800] : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () =>
                              setState(() => _pagamentos.removeAt(i)),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 15, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // Indicador de restante ou troco
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: corFundo,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: corBorda),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        temTroco ? 'Troco:' : 'Restante:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: corDestaque),
                      ),
                      Text(
                        'R\$ ${valorDestaque.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: corDestaque,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Seletor de forma de pagamento
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_erroCarregamento != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erroCarregamento!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _carregando = true;
                            _erroCarregamento = null;
                          });
                          _carregarDados();
                        },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _formaSelecionada,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _formasPagamento.map((f) {
                          final nome = f['nome'] as String;
                          final isPosterior = f['pagamentoPosterior'] as bool;
                          return DropdownMenuItem<String>(
                            value: nome,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(nome,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (isPosterior) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.access_time,
                                      size: 14, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'a receber',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.orange[700]),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _formaSelecionada = v);
                          _valorFocusNode.requestFocus();
                        },
                      ),
                    ),
                    // Conta só aparece quando é escolhida no PDV (não para crediário
                    // nem para formas de conta definida depois, como Dinheiro/Cheque)
                    if (!_semContaNoPdv) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _contaSelecionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Conta',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _contas
                              .map((c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _contaSelecionada = v);
                            _valorFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 12),

              // Campo de valor + botão adicionar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valorCtrl,
                      focusNode: _valorFocusNode,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      // Enter registra a parcela
                      onSubmitted: (_) => _adicionarPagamento(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (!_carregando && _erroCarregamento == null)
                        ? _adicionarPagamento
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                  ),
                ],
              ),

              // Pagador (opcional) — escondido quando a forma é crediário
              // (pagamento posterior), pois ainda não há quem pagou.
              if (!_formaSelecionadaPosterior) ...[
                const SizedBox(height: 16),
                Text(
                  'PAGADOR (SE DIFERENTE DO CLIENTE)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nomePagadorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do pagador',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _cpfPagadorCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'CPF/CNPJ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _podeFinalizar
                        ? () {
                            Navigator.pop(context);
                            widget.onConfirmar(List.of(_pagamentos));
                          }
                        : null,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Finalizar Pagamento'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
