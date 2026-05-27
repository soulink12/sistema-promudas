import 'package:flutter/material.dart';

class TelaVenda extends StatefulWidget {
  const TelaVenda({super.key});

  @override
  State<TelaVenda> createState() => _TelaVendaState();
}

class _TelaVendaState extends State<TelaVenda> {
  // Variável que guarda o cliente após ser pesquisado.
  // Se for nula (null), mostra a barra de pesquisa.
  Map<String, dynamic>? _clienteSelecionado;

  // Lista simulada de clientes para testar a pesquisa localmente
  final List<Map<String, dynamic>> _clientesMock = [
    {'id': 1, 'nome': 'João Silva', 'cpf': '111.111.111-11', 'telefone': '(11) 99999-1111'},
    {'id': 2, 'nome': 'Maria Oliveira', 'cpf': '222.222.222-22', 'telefone': '(22) 98888-2222'},
    {'id': 3, 'nome': 'Carlos Souza', 'cpf': '333.333.333-33', 'telefone': '(33) 97777-3333'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[100],
        titleSpacing: _clienteSelecionado == null ? null : 16, // Ajuste de margem
        title: _clienteSelecionado == null 
            ? const Text('Nova Venda / Encomenda') 
            : _construirDetalhesAppBar(), // Chama a AppBar com os dados
        actions: [
          // Se um cliente estiver selecionado, mostra um botão "X" para limpar
          if (_clienteSelecionado != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black87),
              tooltip: 'Trocar Cliente',
              onPressed: () {
                setState(() {
                  _clienteSelecionado = null; // Volta para a tela de pesquisa
                });
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Se não tem cliente selecionado, mostra o campo de busca.
        // Se tem cliente, mostra o formulário de venda.
        child: _clienteSelecionado == null 
            ? _construirBuscaCliente() 
            : _construirFormularioVenda(),
      ),
    );
  }

  // ----------------------------------------------------
  // WIDGETS AUXILIARES PARA MANTER O CÓDIGO LIMPO
  // ----------------------------------------------------

  // 1. Constrói as informações do cliente na AppBar
  Widget _construirDetalhesAppBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _clienteSelecionado!['nome'] ?? 'Nome não informado',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'CPF: ${_clienteSelecionado!['cpf']} • Tel: ${_clienteSelecionado!['telefone']}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.black87),
        ),
      ],
    );
  }

  // 2. Constrói o campo de pesquisa usando Autocomplete
  Widget _construirBuscaCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Para quem é esta venda?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Autocomplete<Map<String, dynamic>>(
          // A lógica de filtragem: pesquisa por nome, cpf ou telefone
          optionsBuilder: (TextEditingValue valorDigitado) {
            if (valorDigitado.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            final busca = valorDigitado.text.toLowerCase();
            
            return _clientesMock.where((cliente) {
              final nome = cliente['nome'].toString().toLowerCase();
              final cpf = cliente['cpf'].toString().toLowerCase();
              final tel = cliente['telefone'].toString().toLowerCase();
              
              return nome.contains(busca) || cpf.contains(busca) || tel.contains(busca);
            });
          },
          // O que aparece na lista suspensa
          displayStringForOption: (Map<String, dynamic> cliente) => cliente['nome'],
          // O que acontece ao clicar em um cliente da lista
          onSelected: (Map<String, dynamic> clienteEscolhido) {
            setState(() {
              _clienteSelecionado = clienteEscolhido;
            });
          },
          // O visual do campo de texto de pesquisa
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Pesquisar por Nome, CPF ou Telefone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            );
          },
        ),
      ],
    );
  }

  // 3. Constrói o formulário de venda (Que você fará depois)
  Widget _construirFormularioVenda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itens da Encomenda',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        Expanded(
          child: Center(
            child: Text(
              'O formulário de venda para ${_clienteSelecionado!['nome']} entrará aqui.\n\n(Dica: Clique no X lá em cima para trocar de cliente)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}