import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
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
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarClientes() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final response = await ApiService.dio.get('/clientes');
      final dados = response.data as List<dynamic>;
      setState(() {
        _clientes = dados
            .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _carregando = false;
      });

      // Abre direto nos detalhes do cliente quando veio um id inicial
      if (!_selecaoInicialFeita && widget.clienteInicialId != null) {
        _selecaoInicialFeita = true;
        final inicial = _clientes.firstWhere(
          (c) => c['id'] == widget.clienteInicialId,
          orElse: () => {},
        );
        if (inicial.isNotEmpty) _selecionarCliente(inicial);
      }
    } catch (_) {
      setState(() {
        _erroCarregamento = 'Não foi possível carregar os clientes.';
        _carregando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _clientesFiltrados {
    if (_textoBusca.isEmpty) return _clientes;
    final busca = _textoBusca.toLowerCase();
    return _clientes.where((c) {
      return (c['nome'] as String? ?? '').toLowerCase().contains(busca) ||
          (c['cpf_cnpj'] as String? ?? '').toLowerCase().contains(busca) ||
          (c['telefone_1'] as String? ?? '').toLowerCase().contains(busca);
    }).toList();
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
    setState(() {
      _clienteSelecionado = null;
      _editando = false;
      _pedidosCliente = [];
      _buscaController.clear();
      _textoBusca = '';
    });
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
                (e) => Map<String, dynamic>.from(e as Map))
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
      final response =
          await ApiService.dio.put('/clientes/$id', data: body);
      final atualizado =
          Map<String, dynamic>.from(response.data as Map);
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      setState(() => _salvandoEdicao = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar cliente. Tente novamente.'),
            backgroundColor: Colors.red,
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
      MaterialPageRoute(
        builder: (_) => TelaPedidos(clienteInicial: c),
      ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormCadastro,
        tooltip: 'Novo cliente',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _buscaController,
              autofocus: true,
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
              },
            ),
          ),
          Expanded(child: _buildConteudo()),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
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
        clientes: _clientesFiltrados,
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
