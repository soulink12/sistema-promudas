import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/api_feedback.dart';
import '../../../core/utils/enviar_email_documento.dart';
import '../../../core/utils/formatadores.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../../core/widgets/dialog_confirmacao.dart';
import '../../../core/widgets/filtro_multi_status.dart';
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

  @override
  void initState() {
    super.initState();
    _clienteFiltro = widget.clienteInicial;
    _carregarOrcamentos();
  }

  Future<void> _carregarOrcamentos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final params = <String, dynamic>{};
      final clienteNome = _clienteFiltro?['nome'] as String?;
      if (clienteNome != null && clienteNome.isNotEmpty) {
        params['cliente'] = clienteNome;
      }
      if (_numeroFiltro.isNotEmpty) params['numero'] = _numeroFiltro;
      if (_statusFiltro.isNotEmpty) params['status'] = _statusFiltro.join(',');

      final response = await ApiService.dio.get('/orcamentos', queryParameters: params);
      final dados = response.data as List;
      setState(() {
        _orcamentos = dados
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar os orçamentos.';
        _carregando = false;
      });
    }
  }

  Future<void> _recarregarSilencioso(int orcamentoId) async {
    try {
      final response = await ApiService.dio.get('/orcamentos/$orcamentoId');
      final atualizado = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _orcamentoSelecionado = atualizado;
        final idx = _orcamentos.indexWhere((o) => o['id'] == orcamentoId);
        if (idx != -1) _orcamentos[idx] = atualizado;
      });
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

    setState(() => _salvando = true);
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

    setState(() => _salvando = true);
    try {
      await ApiService.dio.post('/orcamentos/${orcamento['id']}/aprovar');
      await _recarregarSilencioso(orcamento['id'] as int);
      setState(() => _salvando = false);
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

    setState(() => _salvando = true);
    try {
      await ApiService.dio.post('/orcamentos/${orcamento['id']}/recusar');
      await _recarregarSilencioso(orcamento['id'] as int);
      setState(() => _salvando = false);
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
                    onEmitirPdf: () => PdfDownloadService.baixarESalvarOrcamento(
                      context,
                      _orcamentoSelecionado!['id'] as int,
                      clienteEmail: _orcamentoSelecionado!['clientes']?['email'] as String?,
                    ),
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
