import 'package:flutter/material.dart';
import '../../../../core/mock/dados_mock.dart';

class BuscaClienteModal extends StatelessWidget {
  // Callback para avisar a tela principal qual cliente foi escolhido
  final Function(Map<String, dynamic>) onClienteSelecionado;

  const BuscaClienteModal({
    super.key,
    required this.onClienteSelecionado,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Faz o modal ocupar apenas o espaço necessário
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
              return DadosMock().clientesMock.where((cliente) {
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
              // 1. Envia o cliente de volta para a tela principal
              onClienteSelecionado(clienteEscolhido);
              // 2. Fecha o modal
              Navigator.pop(context); 
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
  }
}