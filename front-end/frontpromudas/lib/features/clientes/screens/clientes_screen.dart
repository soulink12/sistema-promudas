import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class TelaListaClientes extends StatefulWidget {
  const TelaListaClientes({super.key});

  @override
  State<TelaListaClientes> createState() => _TelaListaClientesState();
}

class _TelaListaClientesState extends State<TelaListaClientes> {
  List<Map<String, dynamic>> _clientes = [];
  bool _carregando = true;
  String? _erroCarregamento;

  final _buscaController = TextEditingController();
  String _textoBusca = '';
  Map<String, dynamic>? _clienteSelecionado;

  // Impede que a mudança programática do campo de busca limpe a seleção
  bool _atualizandoProgramaticamente = false;

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
      _buscaController.text = cliente['nome'] as String? ?? '';
      _textoBusca = '';
    });
    _atualizandoProgramaticamente = false;
  }

  void _limparSelecao() {
    setState(() {
      _clienteSelecionado = null;
      _buscaController.clear();
      _textoBusca = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: Colors.green[100],
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
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erroCarregamento != null
                    ? _buildErro()
                    : _clienteSelecionado != null
                        ? _buildDetalhes(_clienteSelecionado!)
                        : _buildLista(),
          ),
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

  Widget _buildLista() {
    if (_textoBusca.isEmpty) {
      return const Center(
        child: Text(
          'Digite para pesquisar clientes.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    final lista = _clientesFiltrados;
    if (lista.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum cliente encontrado.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: lista.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = lista[index];
        final nome = c['nome'] as String? ?? '';
        final cpf = c['cpf_cnpj'] as String?;
        final tel = c['telefone_1'] as String?;
        final subtitulo = [
          if (cpf != null && cpf.isNotEmpty) cpf,
          if (tel != null && tel.isNotEmpty) tel,
        ].join(' • ');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green[100],
            child: Text(
              _iniciais(nome),
              style: TextStyle(
                  color: Colors.green[800], fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(nome),
          subtitle: subtitulo.isNotEmpty ? Text(subtitulo) : null,
          onTap: () => _selecionarCliente(c),
        );
      },
    );
  }

  Widget _buildDetalhes(Map<String, dynamic> c) {
    final nome = c['nome'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.green[100],
                    child: Text(
                      _iniciais(nome),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('ID: ${c['id']}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              ...[
                _secao('Identificação', [
                  ('CPF / CNPJ', c['cpf_cnpj']),
                  ('Inscrição Estadual', c['inscricao_estadual']),
                ]),
                _secao('Contato', [
                  ('Telefone', c['telefone_1']),
                  ('Telefone 2', c['telefone_2']),
                ]),
                _secao('Endereço', [
                  ('CEP', c['cep']),
                  ('Logradouro', c['logradouro']),
                  ('Número', c['numero']),
                  ('Bairro', c['bairro']),
                  ('Cidade', c['cidade']),
                  ('Estado', c['estado']),
                ]),
                _secao('Sistema', [
                  ('Cadastrado em', _formatarData(c['criado_em'])),
                ]),
              ].whereType<Widget>(),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _secao(String titulo, List<(String, dynamic)> campos) {
    final preenchidos = campos
        .where((f) => f.$2 != null && f.$2.toString().isNotEmpty)
        .toList();
    if (preenchidos.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        ...preenchidos.map((f) => _linha(f.$1, f.$2)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _linha(String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Expanded(
            child: Text(valor.toString(),
                style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  String? _formatarData(dynamic valor) {
    if (valor == null) return null;
    try {
      final dt = DateTime.parse(valor.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return valor.toString();
    }
  }
}
