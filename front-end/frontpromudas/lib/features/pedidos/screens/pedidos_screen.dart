import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../vendas/screens/widgets/modal_busca_cliente.dart';
import '../../vendas/screens/widgets/modal_pagamento.dart';
import 'widgets/lista_pedidos.dart';
import 'widgets/detalhes_pedido.dart';
import '../../../core/services/pdf_download_service.dart';
import '../../vendas/screens/venda_screen.dart';


class TelaPedidos extends StatefulWidget {
  final Map<String, dynamic>? clienteInicial;
  final Map<String, dynamic>? pedidoInicial;

  const TelaPedidos({super.key, this.clienteInicial, this.pedidoInicial});

  @override
  State<TelaPedidos> createState() => _TelaPedidosState();
}

class _TelaPedidosState extends State<TelaPedidos> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  Map<String, dynamic>? _clienteFiltro;
  Map<String, dynamic>? _pedidoSelecionado;

  @override
  void initState() {
    super.initState();
    if (widget.clienteInicial != null) {
      _clienteFiltro = widget.clienteInicial;
      _carregarPedidos(widget.clienteInicial!['nome'] as String?);
    } else {
      _carregarPedidos();
    }
    if (widget.pedidoInicial != null) {
      _pedidoSelecionado = widget.pedidoInicial;
    }
  }

  Future<void> _carregarPedidos([String? clienteNome]) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final response = await ApiService.dio.get(
        '/pedidos',
        queryParameters: clienteNome != null && clienteNome.isNotEmpty
            ? {'cliente': clienteNome}
            : null,
      );
      final dados = response.data as List;
      setState(() {
        _pedidos = dados
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar os pedidos.';
        _carregando = false;
      });
    }
  }

  Future<void> _recarregarSilencioso(int pedidoId) async {
    try {
      final response = await ApiService.dio.get('/pedidos/$pedidoId');
      final atualizado =
          Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _pedidoSelecionado = atualizado;
        final idx = _pedidos.indexWhere((p) => p['id'] == pedidoId);
        if (idx != -1) _pedidos[idx] = atualizado;
      });
    } catch (_) {
      // Falha silenciosa — mantém dados antigos
    }
  }

  void _selecionarClienteFiltro(Map<String, dynamic> cliente) {
    setState(() {
      _clienteFiltro = cliente;
      _pedidoSelecionado = null;
    });
    _carregarPedidos(cliente['nome'] as String?);
  }

  void _limparFiltro() {
    setState(() {
      _clienteFiltro = null;
      _pedidoSelecionado = null;
    });
    _carregarPedidos();
  }

  void _abrirBuscaCliente() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: BuscaClienteModal(
                onClienteSelecionado: _selecionarClienteFiltro,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirModalPagamento(Map<String, dynamic> pedido) {
    final total = _toDouble(pedido['valor_total']);
    final pedidoId = pedido['id'] as int;

    final pagamentos = (pedido['pagamentos'] as List? ?? []);
    final totalPagoReal = pagamentos.fold<double>(0.0, (soma, p) {
      final isPosterior = (p as Map)['pagamento_posterior'] == true;
      return isPosterior ? soma : soma + _toDouble(p['valor_pago']);
    });
    final saldoRestante = (total - totalPagoReal).clamp(0.0, total);

    showDialog<void>(
      context: context,
      builder: (_) => ModalPagamento(
        totalPedido: saldoRestante,
        parcialPermitido: true,
        onConfirmar: (pags) => _registrarPagamento(pedidoId, saldoRestante, pags),
      ),
    );
  }

  Future<void> _abrirEdicaoPedido(Map<String, dynamic> pedido) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaVenda(pedidoParaEditar: pedido),
      ),
    );
    await _recarregarSilencioso(pedido['id'] as int);
  }

  Future<void> _registrarPagamento(
      int pedidoId, double saldoParaPagar, List<Map<String, dynamic>> pagamentos) async {
    setState(() => _salvando = true);

    try {
      final pagamentosReais =
          pagamentos.where((p) => p['pagamentoPosterior'] != true).toList();

      double restante = saldoParaPagar;
      double totalRealPago = 0;
      for (final p in pagamentosReais) {
        if (restante <= 0.005) break;
        final valorPago = (p['valor'] as double).clamp(0.0, restante);
        await ApiService.dio.post('/pagamentos', data: {
          'pedido_id': pedidoId,
          'valor_pago': valorPago,
          'forma_pagamento': p['forma'],
          'data_pagamento': DateTime.now().toUtc().toIso8601String(),
        });
        totalRealPago += valorPago;
        restante -= valorPago;
      }

      final pagamentosAtuais = (_pedidoSelecionado!['pagamentos'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final crediariosExistentes =
          pagamentosAtuais.where((p) => p['pagamento_posterior'] == true).toList();

      if (crediariosExistentes.isNotEmpty) {
        final nomeFormaCredito =
            crediariosExistentes.first['forma_pagamento'] as String;
        final totalCreditoAtual = crediariosExistentes.fold<double>(
            0.0, (s, p) => s + _toDouble(p['valor_pago']));

        for (final c in crediariosExistentes) {
          await ApiService.dio.delete('/pagamentos/${c['id']}');
        }

        final novoSaldoCredito = totalCreditoAtual - totalRealPago;
        if (novoSaldoCredito > 0.005) {
          await ApiService.dio.post('/pagamentos', data: {
            'pedido_id': pedidoId,
            'valor_pago': novoSaldoCredito,
            'forma_pagamento': nomeFormaCredito,
            'data_pagamento': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      await _recarregarSilencioso(pedidoId);
      setState(() => _salvando = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pagamento registrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        await PdfDownloadService.baixarESalvar(context, pedidoId);
      }
    } catch (_) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar pagamento. Tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeCliente = _clienteFiltro?['nome'] as String?;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: InkWell(
          onTap: _abrirBuscaCliente,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nomeCliente ?? 'Todos os pedidos',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      nomeCliente != null
                          ? 'Filtrado por cliente'
                          : 'Últimos 20 pedidos',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        actions: [
          if (_clienteFiltro != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remover filtro',
              onPressed: _limparFiltro,
            ),
        ],
      ),
      body: Stack(
        children: [
          _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
                  ? _buildErro()
                  : _pedidoSelecionado != null
                      ? DetalhesPedido(
                          pedido: _pedidoSelecionado!,
                          salvando: _salvando,
                          onVoltar: () =>
                              setState(() => _pedidoSelecionado = null),
                          onRegistrarPagamento: () =>
                              _abrirModalPagamento(_pedidoSelecionado!),
                          onEmitirPdf: () => PdfDownloadService.baixarESalvar(
                              context, _pedidoSelecionado!['id'] as int),
                          onEditar: () =>
                              _abrirEdicaoPedido(_pedidoSelecionado!),
                        )
                      : ListaPedidos(
                          pedidos: _pedidos,
                          onSelecionarPedido: (p) =>
                              setState(() => _pedidoSelecionado = p),
                        ),
          if (_salvando) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(_erro!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _carregarPedidos,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
