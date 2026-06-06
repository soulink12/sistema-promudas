import 'package:flutter/material.dart';

class TelaListaClientes extends StatefulWidget {
  // Removemos a exigência do token
  const TelaListaClientes({super.key});

  @override
  State<TelaListaClientes> createState() => _TelaListaClientesState();
}

class _TelaListaClientesState extends State<TelaListaClientes> {
  // Mais tarde, esta lista virá do seu banco de dados local (SQLite)
  List<dynamic> _clientes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarClientesLocais();
  }

  // Função que simula a busca no banco offline
  Future<void> _buscarClientesLocais() async {
    // Simulando o tempo de leitura de um banco de dados local
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _clientes = [
        {'id': 1, 'nome': 'Consumidor Padrão', 'telefone': 'Não informado'},
        {'id': 3, 'nome': 'João Silva', 'telefone': '(11) 99999-1111'},
        {'id': 4, 'nome': 'Maria Oliveira', 'telefone': '(22) 98888-2222'},
      ];
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Clientes'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _clientes.length,
              itemBuilder: (context, index) {
                final cliente = _clientes[index];

                return ListTile(
                  title: Text(cliente['nome']),
                  subtitle: Text(cliente['telefone'] ?? 'Sem telefone'),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                    ), 
                  ),
                );
              },
            ),
      // Botão preparado para abrir a futura tela de cadastro offline
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Futuramente: Navigator.push(context, MaterialPageRoute(builder: (_) => CadastroClienteScreen()));
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}