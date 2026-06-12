import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../../core/widgets/dialog_confirmacao.dart';
import '../../vendas/screens/widgets/modal_pagamento.dart';
import 'widgets/lista_pedidos.dart';
import 'widgets/detalhes_pedido.dart';
import 'widgets/dialog_editar_pagamento.dart';
import 'widgets/dialog_nota_fiscal.dart';
import '../../../core/services/pdf_download_service.dart';
import '../../vendas/screens/venda_screen.dart';
import '../../clientes/screens/clientes_screen.dart';

class TelaPedidos extends StatefulWidget {
  final Map<String, dynamic>? clienteInicial;
  final Map<String, dynamic>? pedidoInicial;
  // Filtra a lista por status de pagamento (ex.: 'Pendente,Parcial').
  // Quando informado, a tela mostra só pedidos com pagamento faltando.
  final String? statusPagamentoFiltro;
  // Título do AppBar — permite reaproveitar a tela como "Pagamentos pendentes".
  final String titulo;

  const TelaPedidos({
    super.key,
    this.clienteInicial,
    this.pedidoInicial,
    this.statusPagamentoFiltro,
    this.titulo = 'Pedidos',
  });

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
      final params = <String, dynamic>{};
      if (clienteNome != null && clienteNome.isNotEmpty) {
        params['cliente'] = clienteNome;
      }
      if (widget.statusPagamentoFiltro != null) {
        params['statusPagamento'] = widget.statusPagamentoFiltro;
      }
      final response = await ApiService.dio.get(
        '/pedidos',
        queryParameters: params.isEmpty ? null : params,
      );
      final dados = response.data as List;
      setState(() {
        _pedidos = dados
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
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
      final atualizado = Map<String, dynamic>.from(response.data as Map);
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
        onConfirmar: (pags) =>
            _registrarPagamento(pedidoId, saldoRestante, pags),
      ),
    );
  }

  void _abrirDetalhesCliente(Map<String, dynamic> pedido) {
    final clienteId = pedido['clientes']?['id'] as int?;
    if (clienteId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaListaClientes(clienteInicialId: clienteId),
      ),
    );
  }

  Future<void> _abrirEdicaoPedido(Map<String, dynamic> pedido) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaVenda(pedidoParaEditar: pedido)),
    );
    await _recarregarSilencioso(pedido['id'] as int);
  }

  Future<void> _registrarPagamento(
    int pedidoId,
    double saldoParaPagar,
    List<Map<String, dynamic>> pagamentos,
  ) async {
    setState(() => _salvando = true);

    try {
      final pagamentosReais = pagamentos
          .where((p) => p['pagamentoPosterior'] != true)
          .toList();

      double restante = saldoParaPagar;
      double totalRealPago = 0;
      for (final p in pagamentosReais) {
        if (restante <= 0.005) break;
        final valorPago = (p['valor'] as double).clamp(0.0, restante);
        await ApiService.dio.post(
          '/pagamentos',
          data: {
            'pedido_id': pedidoId,
            'valor_pago': valorPago,
            'forma_pagamento': p['forma'],
            'data_pagamento': DateTime.now().toUtc().toIso8601String(),
            if (p['conta'] != null) 'conta': p['conta'],
            if (p['nomePagador'] != null) 'nome_pagador': p['nomePagador'],
            if (p['cpfPagador'] != null) 'cpf_cnpj_pagador': p['cpfPagador'],
          },
        );
        totalRealPago += valorPago;
        restante -= valorPago;
      }

      final pagamentosAtuais =
          (_pedidoSelecionado!['pagamentos'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      final crediariosExistentes = pagamentosAtuais
          .where((p) => p['pagamento_posterior'] == true)
          .toList();

      if (crediariosExistentes.isNotEmpty) {
        final nomeFormaCredito =
            crediariosExistentes.first['forma_pagamento'] as String;
        final totalCreditoAtual = crediariosExistentes.fold<double>(
          0.0,
          (s, p) => s + _toDouble(p['valor_pago']),
        );

        for (final c in crediariosExistentes) {
          await ApiService.dio.delete('/pagamentos/${c['id']}');
        }

        final novoSaldoCredito = totalCreditoAtual - totalRealPago;
        if (novoSaldoCredito > 0.005) {
          await ApiService.dio.post(
            '/pagamentos',
            data: {
              'pedido_id': pedidoId,
              'valor_pago': novoSaldoCredito,
              'forma_pagamento': nomeFormaCredito,
              'data_pagamento': DateTime.now().toUtc().toIso8601String(),
            },
          );
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

  Future<void> _editarPagamento(Map<String, dynamic> pagamento) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DialogEditarPagamento(pagamento: pagamento),
    );
    if (resultado == null) return;

    final pedidoId = _pedidoSelecionado!['id'] as int;
    setState(() => _salvando = true);
    try {
      await ApiService.dio.put(
        '/pagamentos/${pagamento['id']}',
        data: {
          'valor_pago': resultado['valor_pago'],
          'forma_pagamento': resultado['forma_pagamento'],
          'conta': resultado['conta'],
          'nome_pagador': resultado['nome_pagador'],
          'cpf_cnpj_pagador': resultado['cpf_cnpj_pagador'],
        },
      );
      await _recarregarSilencioso(pedidoId);
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pagamento atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      _mostrarErro(_extrairErro(e, 'Erro ao atualizar pagamento.'));
    }
  }

  Future<void> _excluirPagamento(Map<String, dynamic> pagamento) async {
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Excluir pagamento',
      mensagem:
          'Tem certeza que deseja excluir este pagamento? O status do pedido será recalculado.',
      textoConfirmar: 'Excluir',
    );
    if (!confirmado) return;

    final pedidoId = _pedidoSelecionado!['id'] as int;
    setState(() => _salvando = true);
    try {
      await ApiService.dio.delete('/pagamentos/${pagamento['id']}');
      await _recarregarSilencioso(pedidoId);
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pagamento excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      _mostrarErro(_extrairErro(e, 'Erro ao excluir pagamento.'));
    }
  }

  Future<void> _editarNotaFiscal(Map<String, dynamic> pagamento) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DialogNotaFiscal(pagamento: pagamento),
    );
    if (resultado == null) return;

    final pedidoId = _pedidoSelecionado!['id'] as int;
    setState(() => _salvando = true);
    try {
      await ApiService.dio.put('/pagamentos/${pagamento['id']}', data: {
        'status_nota': resultado['status_nota'],
        'numero_nota': resultado['numero_nota'],
        'data_emissao_nota': resultado['data_emissao_nota'],
      });
      await _recarregarSilencioso(pedidoId);
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota fiscal atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      _mostrarErro(_extrairErro(e, 'Erro ao atualizar nota fiscal.'));
    }
  }

  String _extrairErro(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['erro'] is String) return data['erro'] as String;
    }
    return fallback;
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No detalhe, "voltar" não fecha a tela: volta para a lista de pedidos.
    return PopScope(
      canPop: _pedidoSelecionado == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _pedidoSelecionado = null);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: Stack(
          children: [
            // Em modo detalhe, o DetalhesPedido ocupa a tela inteira (tem seu
            // próprio cabeçalho com voltar). Na listagem, mostramos a busca no topo.
            _pedidoSelecionado != null
                ? DetalhesPedido(
                    pedido: _pedidoSelecionado!,
                    salvando: _salvando,
                    onVoltar: () => setState(() => _pedidoSelecionado = null),
                    onRegistrarPagamento: () =>
                        _abrirModalPagamento(_pedidoSelecionado!),
                    onEmitirPdf: () => PdfDownloadService.baixarESalvar(
                      context,
                      _pedidoSelecionado!['id'] as int,
                    ),
                    onEditar: () => _abrirEdicaoPedido(_pedidoSelecionado!),
                    onTapCliente: () =>
                        _abrirDetalhesCliente(_pedidoSelecionado!),
                    onEditarPagamento: _editarPagamento,
                    onExcluirPagamento: _excluirPagamento,
                    onNotaFiscalPagamento: _editarNotaFiscal,
                  )
                : _buildListagem(),
            if (_salvando) ...[
              const ModalBarrier(dismissible: false, color: Colors.black26),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListagem() {
    return Column(
      children: [
        // Barra de busca/filtro por cliente — sempre visível no topo da lista
        PesquisaClienteLista(
          clienteSelecionado: _clienteFiltro,
          onSelecionado: _selecionarClienteFiltro,
          onLimpar: _limparFiltro,
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
              ? _buildErro()
              : ListaPedidos(
                  pedidos: _pedidos,
                  onSelecionarPedido: (p) =>
                      setState(() => _pedidoSelecionado = p),
                ),
        ),
      ],
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
