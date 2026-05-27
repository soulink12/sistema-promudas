import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class TelaListaClientes extends StatefulWidget {
  final String token;
  const TelaListaClientes({super.key, required this.token});

  @override
  State<TelaListaClientes> createState() => _TelaListaClientesState();
}

class _TelaListaClientesState extends State<TelaListaClientes> {
  late Dio _dio;
  List<dynamic> _clientes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://api2.viveiropromudas.com.br/api',
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ),
    );
    _buscarClientes();
  }

  Future<void> _buscarClientes() async {
    try {
      final response = await _dio.get('/clientes');
      setState(() {
        _clientes = response.data;
        _carregando = false;
      });
    } catch (e) {
      print("Erro: $e");
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      Icons.shopping_cart,
                      color: Colors.white,
                    ), // Mudei o ícone para um carrinho
                  ),
                  // --- ABRE O ECRÃ DE VENDA AO CLICAR ---
                  onTap: () {
                  },
                );
              },
            ),
    );
  }
}
