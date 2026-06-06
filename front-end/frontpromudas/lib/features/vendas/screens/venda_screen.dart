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
    'telefone': 'Não informado',
  };

  // Variável que controla qual cliente está ativo na venda atual
  Map<String, dynamic>? _clienteSelecionado;

  // Lista simulada de clientes para quando o usuário quiser trocar e pesquisar
  final List<Map<String, dynamic>> _clientesMock = [
    {
      'id': 1,
      'nome': 'Consumidor',
      'cpf': 'Não informado',
      'telefone': 'Não informado',
    },
    {
      'id': 3,
      'nome': 'João Silva',
      'cpf': '111.111.111-11',
      'telefone': '(11) 99999-1111',
    },
    {
      'id': 4,
      'nome': 'Maria Oliveira',
      'cpf': '222.222.222-22',
      'telefone': '(22) 98888-2222',
    },
  ];

  final List<Map<String, dynamic>> _produtosMock = [
    {'id': 1, 'nome': 'Muda de Açaí BRS', 'preco': 2.50},
    {'id': 2, 'nome': 'Muda de Cacau Clone', 'preco': 4.00},
    {'id': 3, 'nome': 'Muda de Cupuaçu', 'preco': 3.50},
    {'id': 4, 'nome': 'Semente de Andiroba', 'preco': 1.20},
    {'id': 5, 'nome': 'Muda de Banana Prata', 'preco': 5.00},
    {'id': 6, 'nome': 'Adubo Orgânico 1kg', 'preco': 15.00},
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // A tela de venda está sempre pronta e visível aqui
        child: Column(
          children: <Widget>[
            Expanded(child: _construirFormularioVenda()),
            _construirRodape(),
          ],
        ),
      ),
    );
  }

  Widget _construirDetalhesAppBar() {
    return InkWell(
      // Aqui está a mudança principal: chamamos o modal ao clicar!
      onTap: () {
        _mostrarBuscaClienteModal(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _clienteSelecionado!['nome'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _clienteSelecionado!['id'] == 1
                      ? 'Venda Direta / Balcão'
                      : 'ID: ${_clienteSelecionado!['id']} • CPF: ${_clienteSelecionado!['cpf']} • Tel: ${_clienteSelecionado!['telefone']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(Icons.search, size: 22, color: Colors.black87),
          ],
        ),
      ),
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
            ),
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

  Widget _construirRodape() {
    return Container(
      width: double.infinity,
      color: Colors.green[100],
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Envolvemos no Expanded para o TextField não quebrar a tela na horizontal
          Expanded(
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue valorDigitado) {
                if (valorDigitado.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                final busca = valorDigitado.text.toLowerCase();
                return _produtosMock.where((produto) {
                  final nome = produto['nome'].toString().toLowerCase();
                  final id = produto['id'].toString().toLowerCase();
                  // Permite pesquisar tanto pelo nome da muda quanto pelo código (ID)
                  return nome.contains(busca) || id.contains(busca);
                });
              },
              // O que aparece na lista suspensa e na caixa após selecionar
              displayStringForOption: (Map<String, dynamic> p) => p['nome'],
              onSelected: (Map<String, dynamic> produtoEscolhido) {
                // TODO: Lógica para adicionar o produto na tabela/carrinho
                print(
                  'Produto adicionado: ${produtoEscolhido['nome']} - R\$ ${produtoEscolhido['preco']}',
                );
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Pesquisar Produto (Nome ou Cód.)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors
                            .white, // Deixa a caixa branca contra o fundo verde
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                        ), // Deixa a caixa mais fina
                      ),
                      onEditingComplete: onEditingComplete,
                    );
                  },
            ),
          ),
          const SizedBox(
            width: 16,
          ), // Dá um espaço entre a barra de pesquisa e o texto 2
          const Text(
            'F12 Finalizar', // Substituindo o Teste2
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
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
                'Selecionar Cliente',
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
                    return nome.contains(busca) ||
                        cpf.contains(busca) ||
                        tel.contains(busca);
                  });
                },
                displayStringForOption: (Map<String, dynamic> c) => c['nome'],
                onSelected: (Map<String, dynamic> clienteEscolhido) {
                  setState(() {
                    _clienteSelecionado = clienteEscolhido;
                  });
                  Navigator.pop(context); // Fecha o modal após selecionar
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
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
