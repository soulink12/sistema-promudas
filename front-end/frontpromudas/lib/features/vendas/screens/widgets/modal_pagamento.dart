import 'package:flutter/material.dart';
import '../../../../core/services/forma_pagamento_service.dart';
import '../../../../core/services/conta_service.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';
import '../../../../core/widgets/campo_obrigatorio.dart';
import 'linha_parcela.dart';
import 'campos_cheque.dart';
import 'campos_escambo.dart';

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
  // Nº de parcelas escolhido (só relevante para formas com parceladoEmAte > 1)
  int _parcelasSelecionadas = 1;
  // Detalhes do cheque atual (só formas de depósito posterior). Cada "Adicionar"
  // vira um cheque com estes dados + o valor digitado; os campos zeram depois.
  final TextEditingController _chequeNumeroCtrl = TextEditingController();
  final TextEditingController _chequeBancoCtrl = TextEditingController();
  final TextEditingController _chequeAgenciaCtrl = TextEditingController();
  final TextEditingController _chequeContaCtrl = TextEditingController();
  DateTime? _chequeBomPara;
  // Kg de produção do escambo atual (só formas de escambo). O valor em R$ é
  // calculado pela taxa da forma e preenchido em _valorCtrl.
  final TextEditingController _escamboKgCtrl = TextEditingController();
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
        _formaSelecionada = formas.isNotEmpty
            ? formas.first['nome'] as String
            : null;
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
    _chequeNumeroCtrl.dispose();
    _chequeBancoCtrl.dispose();
    _chequeAgenciaCtrl.dispose();
    _chequeContaCtrl.dispose();
    _escamboKgCtrl.dispose();
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

  // Retorna true se a forma selecionada é de escambo (troca por produção).
  bool get _formaSelecionadaEscambo {
    if (_formaSelecionada == null) return false;
    for (final f in _formasPagamento) {
      if (f['nome'] == _formaSelecionada) {
        return f['escambo'] == true;
      }
    }
    return false;
  }

  // Taxa (R$/kg) da forma de escambo selecionada, ou null se não houver.
  double? get _valorKgEscambo {
    if (_formaSelecionada == null) return null;
    for (final f in _formasPagamento) {
      if (f['nome'] == _formaSelecionada) {
        return f['valorKgEscambo'] as double?;
      }
    }
    return null;
  }

  // Conta não se aplica: crediário (a receber), formas de conta definida depois,
  // ou escambo (não é dinheiro).
  bool get _semContaNoPdv =>
      _formaSelecionadaPosterior ||
      _formaSelecionadaContaPosterior ||
      _formaSelecionadaEscambo;

  // Recalcula o valor em R$ do escambo a partir dos kg digitados e da taxa.
  void _recalcularValorEscambo() {
    final kg = double.tryParse(_escamboKgCtrl.text.trim().replaceAll(',', '.'));
    final taxa = _valorKgEscambo;
    setState(() {
      if (kg != null && kg > 0 && taxa != null && taxa > 0) {
        _valorCtrl.text = (kg * taxa).toStringAsFixed(2);
      } else {
        _valorCtrl.text = '';
      }
    });
  }

  // Retorna true se a forma selecionada é de depósito posterior (cheque) — nesse
  // caso a parcela pode ter cheques e a data do pagamento fica para o depósito.
  bool get _formaSelecionadaDepositoPosterior {
    if (_formaSelecionada == null) return false;
    for (final f in _formasPagamento) {
      if (f['nome'] == _formaSelecionada) {
        return f['depositoPosterior'] == true;
      }
    }
    return false;
  }

  String? _ouNulo(String s) => s.trim().isEmpty ? null : s.trim();

  // Limpa os campos do cheque após adicionar uma parcela (cada cheque é individual).
  void _limparCamposCheque() {
    _chequeNumeroCtrl.clear();
    _chequeBancoCtrl.clear();
    _chequeAgenciaCtrl.clear();
    _chequeContaCtrl.clear();
    _chequeBomPara = null;
  }

  Future<void> _escolherBomPara() async {
    final hoje = DateTime.now();
    final escolhido = await showDatePicker(
      context: context,
      initialDate: _chequeBomPara ?? hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 5),
    );
    if (escolhido != null) setState(() => _chequeBomPara = escolhido);
  }

  // Máximo de parcelas permitido pela forma selecionada (1 = à vista).
  int get _maxParcelasSelecionada {
    if (_formaSelecionada == null) return 1;
    for (final f in _formasPagamento) {
      if (f['nome'] == _formaSelecionada) {
        return (f['parceladoEmAte'] as int? ?? 1).clamp(1, 99);
      }
    }
    return 1;
  }

  // Forma selecionada permite parcelar (libera o dropdown de parcelas).
  bool get _permiteParcelar => _maxParcelasSelecionada > 1;

  double get _totalPago =>
      _pagamentos.fold(0.0, (s, p) => s + (p['valor'] as double));

  double get _restante => widget.totalPedido - _totalPago;

  // Tolerância para imprecisão de ponto flutuante
  bool get _podeFinalizar =>
      widget.parcialPermitido ? _pagamentos.isNotEmpty : _restante < 0.005;

  /// Registra a parcela atual e prepara o campo para a próxima entrada.
  void _adicionarPagamento() {
    if (_formaSelecionada == null) return;
    final valor = double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));
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

    // Parcelas só fazem sentido para formas que permitem parcelar (ex.: crédito).
    final parcelas = _permiteParcelar ? _parcelasSelecionadas : 1;

    // Cheque (forma de depósito posterior): cada "Adicionar" gera um cheque
    // individual com o valor desta parcela + os campos inline.
    final deposito = _formaSelecionadaDepositoPosterior;
    // Escambo: kg de produção recebidos nesta parcela (valor já calculado).
    final escambo = _formaSelecionadaEscambo;
    final escamboKg =
        double.tryParse(_escamboKgCtrl.text.trim().replaceAll(',', '.'));
    final bomParaIso = _chequeBomPara == null
        ? null
        : DateTime(_chequeBomPara!.year, _chequeBomPara!.month,
                _chequeBomPara!.day, 12)
            .toUtc()
            .toIso8601String();

    setState(() {
      _pagamentos.add({
        'forma': _formaSelecionada,
        'valor': valor,
        'pagamentoPosterior': posterior,
        'depositoPosterior': deposito,
        'parcelas': parcelas,
        if (escambo && escamboKg != null) 'escamboQuantidade': escamboKg,
        if (!semConta) 'conta': _contaSelecionada,
        if (!posterior && nomePagador.isNotEmpty) 'nomePagador': nomePagador,
        if (!posterior && cpfPagador.isNotEmpty) 'cpfPagador': cpfPagador,
        if (deposito)
          'cheques': [
            {
              'valor': valor,
              'numero': _ouNulo(_chequeNumeroCtrl.text),
              'banco': _ouNulo(_chequeBancoCtrl.text),
              'agencia': _ouNulo(_chequeAgenciaCtrl.text),
              'conta_corrente': _ouNulo(_chequeContaCtrl.text),
              'bom_para': bomParaIso,
            }
          ],
      });
      final restante = _restante;
      _valorCtrl.text = restante > 0.005 ? restante.toStringAsFixed(2) : '';
      _parcelasSelecionadas = 1;
      _limparCamposCheque();
      _escamboKgCtrl.clear();
      _nomePagadorCtrl.clear();
      _cpfPagadorCtrl.clear();
    });
    _valorFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temTroco = _restante < -0.005;
    final valorDestaque = temTroco ? _restante.abs() : _restante;
    // Verde quando o pagamento cobre o total (ou há troco); laranja enquanto resta.
    final corDestaque = (_podeFinalizar || temTroco)
        ? CoresSemanticas.sucesso
        : CoresSemanticas.aviso;
    final corFundo = corDestaque.withAlpha(30);
    final corBorda = corDestaque.withAlpha(90);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Margem mínima para o modal poder se expandir e usar a altura disponível
      // da janela (o padrão reserva 24px no topo/base, limitando o crescimento)
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          // O modal expande até o limite da janela (insetPadding mínimo) e, se
          // o conteúdo ainda passar disso, rola em vez de estourar.
          child: SingleChildScrollView(
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${formatarMoeda(widget.totalPedido)}',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const Divider(height: 24),

                // Parcelas já registradas
                if (_pagamentos.isNotEmpty) ...[
                  ..._pagamentos.asMap().entries.map(
                        (e) => LinhaParcela(
                          pagamento: e.value,
                          onRemover: () =>
                              setState(() => _pagamentos.removeAt(e.key)),
                        ),
                      ),
                  const SizedBox(height: 8),

                  // Indicador de restante ou troco
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                            fontWeight: FontWeight.w600,
                            color: corDestaque,
                          ),
                        ),
                        Text(
                          formatarMoeda(valorDestaque),
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
                        const Icon(
                          Icons.error_outline,
                          color: CoresSemanticas.erro,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _erroCarregamento!,
                            style: const TextStyle(
                              color: CoresSemanticas.erro,
                              fontSize: 13,
                            ),
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
                                    child: Text(
                                      nome,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isPosterior) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: CoresSemanticas.aviso,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'a receber',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CoresSemanticas.aviso,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _formaSelecionada = v;
                              _parcelasSelecionadas =
                                  1; // reinicia ao trocar de forma
                              _limparCamposCheque(); // cheque é da forma anterior
                              _escamboKgCtrl.clear(); // kg é da forma anterior
                            });
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
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
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

                // Parcelas — só aparece para formas que permitem (ex.: crédito até 6x)
                if (!_carregando &&
                    _erroCarregamento == null &&
                    _permiteParcelar) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _parcelasSelecionadas,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Parcelas',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(_maxParcelasSelecionada, (i) => i + 1)
                        .map(
                          (n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text('${n}x'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _parcelasSelecionadas = v);
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Campo de valor + botão adicionar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: CampoObrigatorio(
                        controller: _valorCtrl,
                        focusNode: _valorFocusNode,
                        autofocus: true,
                        label: 'Valor',
                        prefixText: 'R\$ ',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        // Enter registra a parcela
                        onSubmitted: (_) => _adicionarPagamento(),
                        // Não cobra valor quando o total já está coberto (campo
                        // fica vazio de propósito após zerar o restante).
                        validar: _restante > 0.005,
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
                        backgroundColor: cs.secondary,
                        foregroundColor: cs.onSecondary,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                // Campos do cheque — só para formas de depósito posterior.
                if (_formaSelecionadaDepositoPosterior)
                  CamposCheque(
                    numeroCtrl: _chequeNumeroCtrl,
                    bancoCtrl: _chequeBancoCtrl,
                    agenciaCtrl: _chequeAgenciaCtrl,
                    contaCtrl: _chequeContaCtrl,
                    bomPara: _chequeBomPara,
                    onEscolherData: _escolherBomPara,
                    onLimparData: () => setState(() => _chequeBomPara = null),
                  ),

                // Campo do escambo — só para formas de troca por produção.
                if (_formaSelecionadaEscambo)
                  CamposEscambo(
                    kgCtrl: _escamboKgCtrl,
                    valorKgEscambo: _valorKgEscambo,
                    onKgChange: (_) => _recalcularValorEscambo(),
                  ),

                // Pagador — escondido quando a forma é crediário
                // (pagamento posterior), pois ainda não há quem pagou.
                if (!_formaSelecionadaPosterior) ...[
                  const SizedBox(height: 16),
                  Text(
                    'PAGADOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
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
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
