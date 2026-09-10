import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/forma_pagamento_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/api_feedback.dart';
import '../../../core/utils/enviar_email_documento.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/utils/pagamentos_descartados.dart';
import '../../vendas/screens/widgets/modal_pagamento.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../../core/widgets/dialog_confirmacao.dart';
import '../../../core/widgets/filtro_multi_status.dart';
import '../../../core/widgets/botao_data.dart';
import '../../../core/services/pdf_download_service.dart';
import 'widgets/lista_orcamentos.dart';
import 'widgets/detalhes_orcamento.dart';
import '../../vendas/screens/venda_screen.dart';
import '../../clientes/screens/clientes_screen.dart';
import '../../pedidos/screens/pedidos_screen.dart';

class TelaOrcamentos extends StatefulWidget {
  final Map<String, dynamic>? clienteInicial;

  const TelaOrcamentos({super.key, this.clienteInicial});

  @override
  State<TelaOrcamentos> createState() => _TelaOrcamentosState();
}

class _TelaOrcamentosState extends State<TelaOrcamentos> {
  List<Map<String, dynamic>> _orcamentos = [];
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  Map<String, dynamic>? _clienteFiltro;
  Map<String, dynamic>? _orcamentoSelecionado;

  // Busca por número do orçamento (ex.: "#12") — alternativa à busca por
  // cliente no mesmo campo "Pesquisar".
  String _numeroFiltro = '';

  final Set<String> _statusFiltro = {};

  // Intervalo de datas obrigatório, como na tela de pedidos: sem ele a lista
  // carregava o histórico inteiro a cada abertura.
  late DateTime _de;
  late DateTime _ate;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _ate = DateTime(agora.year, agora.month, agora.day);
    _de = _ate.subtract(const Duration(days: 30));
    _clienteFiltro = widget.clienteInicial;
    _carregarOrcamentos();
  }

  Future<void> _carregarOrcamentos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final clienteNome = _clienteFiltro?['nome'] as String?;
      final buscandoPorCliente = clienteNome != null && clienteNome.isNotEmpty;
      final buscandoPorNumero = _numeroFiltro.isNotEmpty;

      // Busca específica (número ou cliente) ignora o intervalo: senão um
      // orçamento fora da janela padrão não apareceria na procura.
      final params = <String, dynamic>{
        if (!buscandoPorCliente && !buscandoPorNumero) ...{
          'de': _de.toIso8601String(),
          'ate': DateTime(_ate.year, _ate.month, _ate.day, 23, 59, 59)
              .toIso8601String(),
        },
      };
      if (buscandoPorCliente) {
        params['cliente'] = clienteNome;
      }
      if (buscandoPorNumero) {
        params['numero'] = _numeroFiltro;
      }
      if (_statusFiltro.isNotEmpty) params['status'] = _statusFiltro.join(',');

      final response = await ApiService.dio.get('/orcamentos', queryParameters: params);
      final dados = response.data as List;
      if (mounted) {
        setState(() {
          _orcamentos = dados
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os orçamentos.';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _recarregarSilencioso(int orcamentoId) async {
    try {
      final response = await ApiService.dio.get('/orcamentos/$orcamentoId');
      final atualizado = Map<String, dynamic>.from(response.data as Map);
      if (mounted) {
        setState(() {
          _orcamentoSelecionado = atualizado;
          final idx = _orcamentos.indexWhere((o) => o['id'] == orcamentoId);
          if (idx != -1) _orcamentos[idx] = atualizado;
        });
      }
    } catch (_) {
      // Falha silenciosa — mantém dados antigos
    }
  }

  void _selecionarClienteFiltro(Map<String, dynamic> cliente) {
    setState(() {
      _clienteFiltro = cliente;
      _numeroFiltro = '';
      _orcamentoSelecionado = null;
    });
    _carregarOrcamentos();
  }

  void _limparFiltro() {
    setState(() {
      _clienteFiltro = null;
      _numeroFiltro = '';
      _orcamentoSelecionado = null;
    });
    _carregarOrcamentos();
  }

  void _filtrarPorNumero(String texto) {
    if (texto == _numeroFiltro) return;
    setState(() => _numeroFiltro = texto);
    _carregarOrcamentos();
  }

  void _aplicarFiltroStatus(Set<String> selecao) {
    setState(() {
      _statusFiltro
        ..clear()
        ..addAll(selecao);
    });
    _carregarOrcamentos();
  }

  void _abrirDetalhesCliente(Map<String, dynamic> orcamento) {
    final clienteId = orcamento['clientes']?['id'] as int?;
    if (clienteId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaListaClientes(clienteInicialId: clienteId)),
    );
  }

  Future<void> _abrirEdicaoOrcamento(Map<String, dynamic> orcamento) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaVenda(orcamentoParaEditar: orcamento)),
    );
    await _recarregarSilencioso(orcamento['id'] as int);
  }

  Future<void> _excluirOrcamento() async {
    final orcamentoId = _orcamentoSelecionado!['id'] as int;
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Excluir orçamento',
      mensagem:
          'Tem certeza que deseja excluir o Orçamento ${formatarNumeroOrcamento(_orcamentoSelecionado!)}? Esta ação não pode ser desfeita.',
      textoConfirmar: 'Excluir',
    );
    if (!confirmado) return;

    if (mounted) setState(() => _salvando = true);
    try {
      await ApiService.dio.delete('/orcamentos/$orcamentoId');
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _orcamentoSelecionado = null;
      });
      await _carregarOrcamentos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Orçamento excluído com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao excluir o orçamento.'));
    }
  }

  Future<void> _aprovarOrcamento() async {
    final orcamento = _orcamentoSelecionado!;
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Aprovar orçamento',
      mensagem:
          'Tem certeza que deseja aprovar o Orçamento ${formatarNumeroOrcamento(orcamento)}? '
          'Um pedido será criado com os mesmos itens.',
      textoConfirmar: 'Aprovar',
    );
    if (!confirmado) return;

    if (mounted) setState(() => _salvando = true);
    int? pedidoId;
    double totalPedido = 0;
    try {
      final resposta =
          await ApiService.dio.post('/orcamentos/${orcamento['id']}/aprovar');
      pedidoId = resposta.data['pedido_id'] as int?;
      totalPedido = double.tryParse('${resposta.data['valor_total']}') ?? 0;
      await _recarregarSilencioso(orcamento['id'] as int);
      if (mounted) setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Orçamento aprovado! Um pedido foi criado.'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao aprovar o orçamento.'));
      return;
    }

    // Entrada é opcional: se o cliente for pagar algo agora, abre o mesmo modal
    // de pagamento do PDV (exige cobrir o valor todo — o que não for entrada
    // entra como crediário).
    if (pedidoId == null || totalPedido <= 0 || !mounted) return;

    final vaiDarEntrada = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Entrada',
      mensagem: 'O cliente vai dar entrada neste pedido?',
      textoCancelar: 'Não',
      textoConfirmar: 'Sim',
    );
    if (!mounted) return;

    final idPedido = pedidoId;
    final total = totalPedido;

    // Sem entrada, o pedido nasce inteiro no crediário — nenhum pedido fica
    // sem pagamento registrado.
    if (!vaiDarEntrada) {
      await _lancarCrediario(idPedido, total);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => ModalPagamento(
        totalPedido: total,
        onConfirmar: (pagamentos) => _registrarEntrada(idPedido, total, pagamentos),
      ),
    );
  }

  /// Lança o valor todo como crediário no pedido recém-criado pela aprovação.
  Future<void> _lancarCrediario(int pedidoId, double total) async {
    setState(() => _salvando = true);
    try {
      final formas = await FormaPagamentoService().listar();
      final crediario =
          formas.where((f) => f['pagamentoPosterior'] == true).toList();

      if (crediario.isEmpty) {
        if (mounted) setState(() => _salvando = false);
        if (mounted) {
          mostrarErro(
            context,
            'Nenhuma forma de crediário cadastrada. Registre o pagamento manualmente no pedido.',
          );
        }
        return;
      }

      await ApiService.dio.post('/pagamentos', data: {
        'pedido_id': pedidoId,
        'valor_pago': total,
        'forma_pagamento': crediario.first['nome'],
        'data_pagamento': DateTime.now().toUtc().toIso8601String(),
      });

      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${crediario.first['nome']} de ${formatarMoeda(total)} lançado no pedido.',
            ),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        mostrarErro(context, extrairErroApi(e, 'Erro ao lançar o crediário.'));
      }
    }
  }

  Future<void> _registrarEntrada(
    int pedidoId,
    double total,
    List<Map<String, dynamic>> pagamentos,
  ) async {
    setState(() => _salvando = true);
    try {
      double restante = total;
      for (final p in pagamentos) {
        if (restante <= 0.005) break;
        final valorPago = (p['valor'] as double).clamp(0.0, restante);
        await ApiService.dio.post('/pagamentos', data: {
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
        });
        restante -= valorPago;
      }

      if (mounted) setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrada registrada com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
        if (haPagamentosDescartados(pagamentos, total)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Valor de troco não registrado como pagamento.'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        mostrarErro(context, extrairErroApi(e, 'Erro ao registrar a entrada.'));
      }
    }
  }

  Future<void> _recusarOrcamento() async {
    final orcamento = _orcamentoSelecionado!;
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Recusar orçamento',
      mensagem:
          'Tem certeza que deseja recusar o Orçamento ${formatarNumeroOrcamento(orcamento)}? '
          'Esta ação não pode ser desfeita.',
      textoConfirmar: 'Recusar',
    );
    if (!confirmado) return;

    if (mounted) setState(() => _salvando = true);
    try {
      await ApiService.dio.post('/orcamentos/${orcamento['id']}/recusar');
      await _recarregarSilencioso(orcamento['id'] as int);
      if (mounted) setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Orçamento recusado.'),
            backgroundColor: CoresSemanticas.aviso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao recusar o orçamento.'));
    }
  }

  Future<void> _enviarEmailOrcamento() async {
    final orcamento = _orcamentoSelecionado!;
    final email = orcamento['clientes']?['email'] as String?;
    if (email == null || email.isEmpty) return;

    setState(() => _salvando = true);
    await enviarDocumentoPorEmail(
      context: context,
      caminho: '/orcamentos/${orcamento['id']}/enviar-email',
      nomeDocumento: 'Orçamento ${formatarNumeroOrcamento(orcamento)}',
      email: email,
    );
    if (mounted) setState(() => _salvando = false);
  }

  Future<void> _emitirPdfOrcamento() async {
    setState(() => _salvando = true);
    await PdfDownloadService.baixarESalvarOrcamento(
      context,
      _orcamentoSelecionado!['id'] as int,
      clienteEmail: _orcamentoSelecionado!['clientes']?['email'] as String?,
    );
    if (mounted) setState(() => _salvando = false);
  }

  Future<void> _verPedidoGerado() async {
    final pedidoId = _orcamentoSelecionado!['pedido_id'] as int?;
    if (pedidoId == null) return;
    try {
      final response = await ApiService.dio.get('/pedidos/$pedidoId');
      final pedido = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TelaPedidos(pedidoInicial: pedido)),
      );
    } catch (e) {
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Não foi possível abrir o pedido.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // No detalhe, "voltar" não fecha a tela: volta para a lista de orçamentos.
    return PopScope(
      canPop: _orcamentoSelecionado == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _orcamentoSelecionado = null);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Orçamentos')),
        body: Stack(
          children: [
            _orcamentoSelecionado != null
                ? DetalhesOrcamento(
                    orcamento: _orcamentoSelecionado!,
                    salvando: _salvando,
                    onVoltar: () => setState(() => _orcamentoSelecionado = null),
                    onEmitirPdf: _emitirPdfOrcamento,
                    onEnviarEmail: _enviarEmailOrcamento,
                    onEditar: () => _abrirEdicaoOrcamento(_orcamentoSelecionado!),
                    onExcluir: _excluirOrcamento,
                    onAprovar: _aprovarOrcamento,
                    onRecusar: _recusarOrcamento,
                    onTapCliente: () => _abrirDetalhesCliente(_orcamentoSelecionado!),
                    onVerPedidoGerado: _verPedidoGerado,
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

  Future<void> _selecionarData(bool isDe) async {
    final data = await showDatePicker(
      context: context,
      initialDate: isDe ? _de : _ate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;
    if (mounted) {
      setState(() {
        if (isDe) {
          _de = data;
          if (_ate.isBefore(_de)) _ate = _de;
        } else {
          _ate = data;
          if (_de.isAfter(_ate)) _de = _ate;
        }
      });
    }
    _carregarOrcamentos();
  }

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Widget _buildListagem() {
    return Column(
      children: [
        PesquisaClienteLista(
          clienteSelecionado: _clienteFiltro,
          onSelecionado: _selecionarClienteFiltro,
          onLimpar: _limparFiltro,
          labelText: 'Pesquisar',
          hintText: 'Nome do cliente ou número do orçamento',
          onTextoNumerico: _filtrarPorNumero,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: FiltroMultiStatus(
            rotulo: 'Status',
            opcoes: const ['Pendente', 'Aprovado', 'Rejeitado'],
            selecionados: _statusFiltro,
            onChanged: _aplicarFiltroStatus,
          ),
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
              ? _buildErro()
              : ListaOrcamentos(
                  orcamentos: _orcamentos,
                  onSelecionarOrcamento: (o) => setState(() => _orcamentoSelecionado = o),
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
            onPressed: _carregarOrcamentos,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
