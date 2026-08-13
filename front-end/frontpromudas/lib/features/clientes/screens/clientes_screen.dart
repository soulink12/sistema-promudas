import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../pedidos/screens/pedidos_screen.dart';
import 'widgets/lista_clientes.dart';
import 'widgets/detalhes_cliente.dart';
import 'widgets/form_edicao_cliente.dart';
import 'widgets/dialog_cadastro_cliente.dart';

class TelaListaClientes extends StatefulWidget {
  /// Quando informado, a tela abre já exibindo os detalhes deste cliente.
  final int? clienteInicialId;

  const TelaListaClientes({super.key, this.clienteInicialId});

  @override
  State<TelaListaClientes> createState() => _TelaListaClientesState();
}

class _TelaListaClientesState extends State<TelaListaClientes> {
  List<Map<String, dynamic>> _clientes = [];
  bool _carregando = true;
  String? _erroCarregamento;

  List<Map<String, dynamic>> _pedidosCliente = [];
  bool _carregandoPedidos = false;

  final _buscaController = TextEditingController();
  String _textoBusca = '';
  Timer? _debounce;
  Map<String, dynamic>? _clienteSelecionado;

  // Impede que a mudança programática do campo de busca limpe a seleção
  bool _atualizandoProgramaticamente = false;

  bool _editando = false;
  bool _salvandoEdicao = false;

  // Garante que a pré-seleção por id ocorra apenas no primeiro carregamento
  bool _selecaoInicialFeita = false;

  @override
  void initState() {
    super.initState();
    _carregarClientes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  /// Carrega os clientes. Sem [busca], traz os 20 últimos cadastrados;
  /// com [busca], pesquisa no backend (nome, CPF/CNPJ ou telefone).
  Future<void> _carregarClientes([String? busca]) async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final response = await ApiService.dio.get(
        '/clientes',
        queryParameters: (busca != null && busca.isNotEmpty)
            ? {'busca': busca}
            : null,
      );
      final dados = response.data as List<dynamic>;
      setState(() {
        _clientes = dados
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();
        _carregando = false;
      });

      await _preSelecionarInicial();
    } catch (_) {
      setState(() {
        _erroCarregamento = 'Não foi possível carregar os clientes.';
        _carregando = false;
      });
    }
  }

  /// Abre direto nos detalhes quando a tela recebe um [clienteInicialId].
  /// Como a lista mostra só os 20 recentes, busca o cliente pelo id se ele
  /// não estiver entre os carregados.
  Future<void> _preSelecionarInicial() async {
    if (_selecaoInicialFeita || widget.clienteInicialId == null) return;
    _selecaoInicialFeita = true;

    var inicial = _clientes.firstWhere(
      (c) => c['id'] == widget.clienteInicialId,
      orElse: () => {},
    );

    if (inicial.isEmpty) {
      try {
        final resp = await ApiService.dio.get(
          '/clientes/${widget.clienteInicialId}',
        );
        inicial = Map<String, dynamic>.from(resp.data as Map);
      } catch (_) {
        return;
      }
    }

    if (inicial.isNotEmpty && mounted) _selecionarCliente(inicial);
  }

  void _selecionarCliente(Map<String, dynamic> cliente) {
    _atualizandoProgramaticamente = true;
    setState(() {
      _clienteSelecionado = cliente;
      _editando = false;
      _pedidosCliente = [];
      _buscaController.text = cliente['nome'] as String? ?? '';
      _textoBusca = '';
    });
    _atualizandoProgramaticamente = false;
    _carregarPedidosCliente(cliente['nome'] as String? ?? '');
  }

  void _limparSelecao() {
    _debounce?.cancel();
    setState(() {
      _clienteSelecionado = null;
      _editando = false;
      _pedidosCliente = [];
      _buscaController.clear();
      _textoBusca = '';
    });
    _carregarClientes(); // volta a mostrar os 20 mais recentes
  }

  Future<void> _carregarPedidosCliente(String nome) async {
    setState(() => _carregandoPedidos = true);
    try {
      final response = await ApiService.dio.get(
        '/pedidos',
        queryParameters: {'cliente': nome},
      );
      final dados = response.data as List;
      setState(() {
        _pedidosCliente = dados
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
        _carregandoPedidos = false;
      });
    } catch (_) {
      setState(() => _carregandoPedidos = false);
    }
  }

  Future<void> _salvarEdicao(Map<String, dynamic> body) async {
    setState(() => _salvandoEdicao = true);
    try {
      final id = _clienteSelecionado!['id'];
      final response = await ApiService.dio.put('/clientes/$id', data: body);
      final atualizado = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _clienteSelecionado = atualizado;
        _editando = false;
        _salvandoEdicao = false;
      });
      _carregarClientes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente atualizado com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } on DioException catch (e) {
      setState(() => _salvandoEdicao = false);
      if (mounted) {
        final mensagem = e.response?.data?['erro'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensagem ?? 'Erro ao atualizar cliente. Tente novamente.',
            ),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    } catch (_) {
      setState(() => _salvandoEdicao = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar cliente. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    }
  }

  Future<void> _navegarParaPedido(Map<String, dynamic> pedido) async {
    final c = _clienteSelecionado!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaPedidos(clienteInicial: c, pedidoInicial: pedido),
      ),
    );
    if (mounted && _clienteSelecionado != null) {
      _carregarPedidosCliente(_clienteSelecionado!['nome'] as String? ?? '');
    }
  }

  Future<void> _verTodosPedidos() async {
    final c = _clienteSelecionado!;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaPedidos(clienteInicial: c)),
    );
    if (mounted && _clienteSelecionado != null) {
      _carregarPedidosCliente(_clienteSelecionado!['nome'] as String? ?? '');
    }
  }

  Future<void> _abrirFormCadastro() async {
    final criado = await showDialog<bool>(
      context: context,
      builder: (_) => const DialogCadastroCliente(),
    );
    if (criado == true) _carregarClientes();
  }

  @override
  Widget build(BuildContext context) {
    // No detalhe/edição, "voltar" não fecha a tela: volta para a lista.
    return PopScope(
      canPop: _clienteSelecionado == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_editando) {
          setState(() => _editando = false);
        } else {
          _limparSelecao();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        floatingActionButton: FloatingActionButton(
          onPressed: _abrirFormCadastro,
          tooltip: 'Novo cliente',
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Topo: barra de busca na listagem; cabeçalho com nome ao ver detalhes
            if (_clienteSelecionado == null)
              _buildBusca()
            else
              _buildCabecalhoCliente(),
            Expanded(child: _buildConteudo()),
          ],
        ),
      ),
    );
  }

  /// Barra de busca exibida na listagem de clientes.
  Widget _buildBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _buscaController,
        decoration: InputDecoration(
          hintText: 'Buscar por nome, CPF ou telefone...',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: _buscaController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Limpar',
                  onPressed: _limparSelecao,
                )
              : null,
        ),
        onChanged: (texto) {
          if (_atualizandoProgramaticamente) return;
          setState(() {
            _textoBusca = texto;
            _clienteSelecionado = null;
          });
          // Debounce para não consultar a API a cada tecla
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () {
            _carregarClientes(texto.trim());
          });
        },
      ),
    );
  }

  /// Cabeçalho exibido ao ver/editar um cliente: seta de voltar + nome em
  /// destaque, no mesmo padrão dos detalhes do pedido.
  Widget _buildCabecalhoCliente() {
    final cs = Theme.of(context).colorScheme;
    final nome = _clienteSelecionado!['nome'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar para a lista',
            onPressed: _editando
                ? () => setState(() => _editando = false)
                : _limparSelecao,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              nome,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());

    if (_erroCarregamento != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: CoresSemanticas.erro,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(_erroCarregamento!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _carregarClientes,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_clienteSelecionado == null) {
      return ListaClientes(
        clientes: _clientes,
        textoBusca: _textoBusca,
        onSelecionarCliente: _selecionarCliente,
      );
    }

    if (_editando) {
      return FormEdicaoCliente(
        cliente: _clienteSelecionado!,
        salvando: _salvandoEdicao,
        onSalvar: _salvarEdicao,
        onCancelar: () => setState(() => _editando = false),
      );
    }

    return DetalhesCliente(
      cliente: _clienteSelecionado!,
      pedidosCliente: _pedidosCliente,
      carregandoPedidos: _carregandoPedidos,
      onIniciarEdicao: () => setState(() => _editando = true),
      onTapPedido: _navegarParaPedido,
      onVerTodosPedidos: _verTodosPedidos,
    );
  }
}
