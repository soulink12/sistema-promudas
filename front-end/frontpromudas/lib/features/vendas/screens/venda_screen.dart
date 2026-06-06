import 'package:flutter/material.dart';

class TelaVenda extends StatefulWidget {
  const TelaVenda({super.key});

  @override
  State<TelaVenda> createState() => _TelaVendaState();
}

class _TelaVendaState extends State<TelaVenda> {
  // Define a estrutura do seu Consumidor Padrão
  final Map<String, dynamic> _consumidorPadrao = {
    'id': 1,
    'nome': 'Consumidor',
    'cpf': 'Não informado',
    'telefone': 'Não informado'
  };

  // Variável que controla qual cliente está ativo na venda atual
  Map<String, dynamic>? _clienteSelecionado;

  // Lista simulada de clientes para quando o usuário quiser trocar e pesquisar
final List<Map<String, dynamic>> _clientesMock = [
    {'id': 1, 'nome': 'Consumidor', 'cpf': 'Não informado', 'telefone': 'Não informado'},
    {'id': 3, 'nome': 'João Silva', 'cpf': '111.111.111-11', 'telefone': '(11) 99999-1111'},
    {'id': 4, 'nome': 'Maria Oliveira', 'cpf': '222.222.222-22', 'telefone': '(22) 98888-2222'},
  ];

  @override
  void initState() {
    super.initState();
    // Assim que a tela abre, o cliente padrão já é selecionado automaticamente
    _clienteSelecionado = _consumidorPadrao;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[100],
        titleSpacing: 16,
        title: _construirDetalhesAppBar(),
        actions: [
          // Botão para trocar de cliente ou voltar para o padrão
          IconButton(
            icon: Icon(
              _clienteSelecionado!['id'] == 1 ? Icons.person_search : Icons.clear, 
              color: Colors.black87
            ),
            tooltip: _clienteSelecionado!['id'] == 1 ? 'Mudar Cliente' : 'Voltar para Consumidor',
            onPressed: () {
              if (_clienteSelecionado!['id'] == 1) {
                // Se está no padrão, abre uma janela/modal de busca para escolher outro
                _mostrarBuscaClienteModal(context);
              } else {
                // Se está em outro cliente, o botão "X" retorna instantaneamente para o padrão
                setState(() {
                  _clienteSelecionado = _consumidorPadrao;
                });
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // A tela de venda está sempre pronta e visível aqui
        child: _construirFormularioVenda(),
      ),
    );
  }

  // 1. Monta o cabeçalho dinâmico na AppBar
  Widget _construirDetalhesAppBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _clienteSelecionado!['nome'],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          _clienteSelecionado!['id'] == 1
              ? 'Venda Direta / Balcão'
              :'ID: ${_clienteSelecionado!['id']} • CPF: ${_clienteSelecionado!['cpf']} • Tel: ${_clienteSelecionado!['telefone']}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.black87),
        ),
      ],
    );
  }

  // 2. O formulário de venda propriamente dito (Sempre ativo no body)
  Widget _construirFormularioVenda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Itens da Venda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            )
          ],
        ),
        const Divider(),
        
        // Espaço reservado para a inserção das mudas, quantidades e cálculos
        Expanded(
          child: Center(
            child: Text(
              'O formulário de venda está pronto para uso.\nFaturamento atual para: ${_clienteSelecionado!['nome']}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // 3. Caixa de diálogo (Modal) para buscar outro cliente sem sair da venda
  void _mostrarBuscaClienteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecionar Cliente Especial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
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
                displayStringForOption: (Map<String, dynamic> c) => c['nome'],
                onSelected: (Map<String, dynamic> clienteEscolhido) {
                  setState(() {
                    _clienteSelecionado = clienteEscolhido;
                  });
                  Navigator.pop(context); // Fecha o modal após selecionar
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Digite Nome, CPF ou Telefone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}