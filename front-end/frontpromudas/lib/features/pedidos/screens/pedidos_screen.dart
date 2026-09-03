import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/temporada_service.dart';
import '../../../core/services/forma_pagamento_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/api_feedback.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../../core/widgets/dialog_confirmacao.dart';
import '../../../core/widgets/filtro_multi_status.dart';
import '../../../core/widgets/botao_data.dart';
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

  // Busca por número do pedido (ex.: "26-1" ou "#12") — alternativa à busca por
  // cliente no mesmo campo "Pesquisar". Vazio = sem filtro.
  String _numeroFiltro = '';

  // Filtros de status (seleção múltipla). Vazio = sem filtro. Todos filtrados no backend.
  final Set<String> _statusPagamento = {};
  final Set<String> _statusEntrega = {};
  final Set<String> _statusNota = {};

  // Opções (carregadas da API) e seleção dos filtros de temporada/forma de pagamento.
  List<Map<String, dynamic>> _temporadas = [];
  List<Map<String, dynamic>> _formasPagamento = [];
  final Set<String> _temporadasFiltro = {};
  final Set<String> _formaPagamentoFiltro = {};

  // Intervalo de datas — obrigatório. Padrão: última semana (hoje − 7 dias … hoje).
  late DateTime _de;
  late DateTime _ate;

  @override
  void initState() {
    super.initState();
    _clienteFiltro = widget.clienteInicial;
    final agora = DateTime.now();
    _ate = DateTime(agora.year, agora.month, agora.day);
    _de = _ate.subtract(const Duration(days: 7));
    // Semeia o filtro de pagamento quando a tela já abre filtrada
    // (ex.: "Pagamentos pendentes" passa 'Pendente,Parcial').
    if (widget.statusPagamentoFiltro != null) {
      _statusPagamento.addAll(widget.statusPagamentoFiltro!.split(','));
    }
    _carregarPedidos();
    _carregarOpcoesFiltro();
    if (widget.pedidoInicial != null) {
      _pedidoSelecionado = widget.pedidoInicial;
    }
  }

  // Carrega as opções dos filtros de temporada e forma de pagamento. Falha
  // silenciosa — nesse caso os filtros extras simplesmente não aparecem.
  Future<void> _carregarOpcoesFiltro() async {
    try {
      final resultados = await Future.wait([
        TemporadaService().listar(),
        FormaPagamentoService().listar(),
      ]);
      if (!mounted) return;
      setState(() {
        _temporadas = resultados[0];
        _formasPagamento = resultados[1];
      });
    } catch (_) {
      // Ignorado — resto da tela funciona normalmente.
    }
  }

  Future<void> _carregarPedidos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final params = <String, dynamic>{
        'de': _de.toIso8601String(),
        // Inclui o dia inteiro do "até".
        'ate': DateTime(_ate.year, _ate.month, _ate.day, 23, 59, 59)
            .toIso8601String(),
      };
      final clienteNome = _clienteFiltro?['nome'] as String?;
      if (clienteNome != null && clienteNome.isNotEmpty) {
        params['cliente'] = clienteNome;
      }
      if (_numeroFiltro.isNotEmpty) {
        params['numero'] = _numeroFiltro;
      }
      if (_statusPagamento.isNotEmpty) {
        params['statusPagamento'] = _statusPagamento.join(',');
      }
      if (_statusEntrega.isNotEmpty) {
        params['statusEntrega'] = _statusEntrega.join(',');
      }
      if (_statusNota.isNotEmpty) {
        params['statusNota'] = _statusNota.join(',');
      }
      if (_temporadasFiltro.isNotEmpty) {
        params['temporadaAno'] = _temporadasFiltro.join(',');
      }
      if (_formaPagamentoFiltro.isNotEmpty) {
        params['formaPagamento'] = _formaPagamentoFiltro.join(',');
      }
      final response = await ApiService.dio.get(
        '/pedidos',
        queryParameters: params,
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
      _numeroFiltro = '';
      _pedidoSelecionado = null;
    });
    _carregarPedidos();
  }

  void _limparFiltro() {
    setState(() {
      _clienteFiltro = null;
      _numeroFiltro = '';
      _pedidoSelecionado = null;
    });
    _carregarPedidos();
  }

  // Busca por número do pedido, digitado no mesmo campo "Pesquisar".
  void _filtrarPorNumero(String texto) {
    if (texto == _numeroFiltro) return;
    setState(() => _numeroFiltro = texto);
    _carregarPedidos();
  }

  Future<void> _selecionarData(bool isDe) async {
    final data = await showDatePicker(
      context: context,
      initialDate: isDe ? _de : _ate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;
    setState(() {
      if (isDe) {
        _de = data;
        if (_ate.isBefore(_de)) _ate = _de;
      } else {
        _ate = data;
        if (_de.isAfter(_ate)) _de = _ate;
      }
    });
    _carregarPedidos();
  }

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // Substitui o conteúdo de um filtro de status e recarrega (todos no backend).
  void _aplicarFiltroStatus(Set<String> filtro, Set<String> selecao) {
    setState(() {
      filtro
        ..clear()
        ..addAll(selecao);
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
            // Cheque (depósito posterior): data fica nula até o depósito.
            if (p['depositoPosterior'] != true)
              'data_pagamento': DateTime.now().toUtc().toIso8601String(),
            if (p['parcelas'] != null) 'parcelas': p['parcelas'],
            if (p['escamboQuantidade'] != null)
              'escambo_quantidade': p['escamboQuantidade'],
            if (p['conta'] != null) 'conta': p['conta'],
            if (p['nomePagador'] != null) 'nome_pagador': p['nomePagador'],
            if (p['cpfPagador'] != null) 'cpf_cnpj_pagador': p['cpfPagador'],
            if (p['cheques'] != null) 'cheques': p['cheques'],
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
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
        await PdfDownloadService.baixarESalvar(
          context,
          pedidoId,
          clienteEmail: _pedidoSelecionado?['clientes']?['email'] as String?,
        );
      }
    } catch (_) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar pagamento. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _editarDataPedido(DateTime novaData) async {
    final pedidoId = _pedidoSelecionado!['id'] as int;
    setState(() => _salvando = true);
    try {
      await ApiService.dio.put('/pedidos/$pedidoId', data: {
        'data_pedido': novaData.toUtc().toIso8601String(),
      });
      await _recarregarSilencioso(pedidoId);
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data do pedido atualizada com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao atualizar a data do pedido.'));
    }
  }

  // Troca a temporada do pedido (numeração 26-1, 27-1…). O backend recomputa o
  // numero_temporada na temporada escolhida.
  Future<void> _editarTemporadaPedido() async {
    final pedidoId = _pedidoSelecionado!['id'] as int;
    final atual = _pedidoSelecionado!['temporada_ano'] as int?;

    List<Map<String, dynamic>> temporadas;
    try {
      temporadas = await TemporadaService().listar();
    } catch (e) {
      if (mounted) {
        mostrarErro(context, extrairErroApi(e, 'Erro ao carregar temporadas.'));
      }
      return;
    }
    if (temporadas.isEmpty) {
      if (mounted) {
        mostrarErro(context,
            'Nenhuma temporada cadastrada. Cadastre uma em Configurações do Sistema.');
      }
      return;
    }
    if (!mounted) return;

    int? selecionado = atual ?? temporadas.first['ano'] as int;
    final escolhido = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Temporada do pedido'),
          content: DropdownButtonFormField<int>(
            initialValue: selecionado,
            decoration: const InputDecoration(
              labelText: 'Temporada',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: temporadas.map((t) {
              final ano = t['ano'] as int;
              final aa = (ano % 100).toString().padLeft(2, '0');
              return DropdownMenuItem(value: ano, child: Text('$ano  ($aa-N)'));
            }).toList(),
            onChanged: (v) => setLocal(() => selecionado = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selecionado),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (escolhido == null || escolhido == atual) return;
    setState(() => _salvando = true);
    try {
      await ApiService.dio
          .put('/pedidos/$pedidoId', data: {'temporada_ano': escolhido});
      await _recarregarSilencioso(pedidoId);
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temporada do pedido atualizada!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        mostrarErro(context,
            extrairErroApi(e, 'Erro ao atualizar a temporada do pedido.'));
      }
    }
  }

  // Exclui o pedido (soft-delete no backend) após confirmação. Volta para a
  // lista e recarrega, já que o pedido aberto deixa de existir.
  Future<void> _excluirPedido() async {
    final pedidoId = _pedidoSelecionado!['id'] as int;
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Excluir pedido',
      mensagem:
          'Tem certeza que deseja excluir o Pedido ${formatarNumeroPedido(_pedidoSelecionado!)}? Esta ação não pode ser desfeita.',
      textoConfirmar: 'Excluir',
    );
    if (!confirmado) return;

    setState(() => _salvando = true);
    try {
      await ApiService.dio.delete('/pedidos/$pedidoId');
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _pedidoSelecionado = null;
      });
      await _carregarPedidos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido excluído com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        mostrarErro(context, extrairErroApi(e, 'Erro ao excluir o pedido.'));
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
          'data_pagamento': resultado['data_pagamento'],
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
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao atualizar pagamento.'));
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
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao excluir pagamento.'));
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
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao atualizar nota fiscal.'));
    }
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
                      clienteEmail: _pedidoSelecionado!['clientes']?['email'] as String?,
                    ),
                    onEditar: () => _abrirEdicaoPedido(_pedidoSelecionado!),
                    onExcluir: _excluirPedido,
                    onTapCliente: () =>
                        _abrirDetalhesCliente(_pedidoSelecionado!),
                    onEditarData: _editarDataPedido,
                    onEditarTemporada: _editarTemporadaPedido,
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
        // Barra de busca — cliente ou número do pedido — sempre visível no topo da lista
        PesquisaClienteLista(
          clienteSelecionado: _clienteFiltro,
          onSelecionado: _selecionarClienteFiltro,
          onLimpar: _limparFiltro,
          labelText: 'Pesquisar',
          hintText: 'Nome do cliente ou número do pedido',
          onTextoNumerico: _filtrarPorNumero,
        ),
        // Filtros (datas obrigatórias + status) — logo abaixo da pesquisa
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: BotaoData(
                      label: 'De',
                      valor: _formatarData(_de),
                      selecionado: true,
                      onTap: () => _selecionarData(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BotaoData(
                      label: 'Até',
                      valor: _formatarData(_ate),
                      selecionado: true,
                      onTap: () => _selecionarData(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FiltroMultiStatus(
                    rotulo: 'Status de pagamento',
                    opcoes: const ['Pago', 'Crédito', 'Parcial', 'Pendente'],
                    selecionados: _statusPagamento,
                    onChanged: (sel) => _aplicarFiltroStatus(_statusPagamento, sel),
                  ),
                  FiltroMultiStatus(
                    rotulo: 'Status de entrega',
                    opcoes: const ['Entregue', 'Parcial', 'Pendente'],
                    selecionados: _statusEntrega,
                    onChanged: (sel) => _aplicarFiltroStatus(_statusEntrega, sel),
                  ),
                  FiltroMultiStatus(
                    rotulo: 'Status da nota',
                    opcoes: const [
                      'Emitida',
                      'Parcial',
                      'Pendente',
                      'Processando',
                      'Rejeitada',
                    ],
                    selecionados: _statusNota,
                    onChanged: (sel) => _aplicarFiltroStatus(_statusNota, sel),
                  ),
                  if (_temporadas.isNotEmpty)
                    FiltroMultiStatus(
                      rotulo: 'Temporada',
                      opcoes: _temporadas
                          .map((t) => (t['ano'] as int).toString())
                          .toList(),
                      selecionados: _temporadasFiltro,
                      onChanged: (sel) =>
                          _aplicarFiltroStatus(_temporadasFiltro, sel),
                    ),
                  if (_formasPagamento.isNotEmpty)
                    FiltroMultiStatus(
                      rotulo: 'Forma de pagamento',
                      opcoes: _formasPagamento
                          .map((f) => f['nome'] as String)
                          .toList(),
                      selecionados: _formaPagamentoFiltro,
                      onChanged: (sel) =>
                          _aplicarFiltroStatus(_formaPagamentoFiltro, sel),
                    ),
                ],
              ),
            ],
          ),
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
          const Icon(Icons.error_outline, color: CoresSemanticas.erro, size: 40),
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
