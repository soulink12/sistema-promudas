import 'package:flutter/material.dart';
import '../../../../core/mock/dados_mock.dart';

/// Popup de busca de clientes exibido próximo à AppBar.
/// Permite ao operador pesquisar um cliente por nome, CPF ou telefone
/// e vinculá-lo à venda em andamento.
class BuscaClienteModal extends StatefulWidget {
  // Callback para avisar a tela principal qual cliente foi escolhido
  final Function(Map<String, dynamic>) onClienteSelecionado;

  const BuscaClienteModal({
    super.key,
    required this.onClienteSelecionado,
  });

  @override
  State<BuscaClienteModal> createState() => _BuscaClienteModalState();
}

class _BuscaClienteModalState extends State<BuscaClienteModal> {
  // Evita dupla seleção quando onEditingComplete + onSubmitted disparam juntos
  bool _selecionado = false;

  /// Filtra clientes pelo texto digitado (nome, CPF ou telefone).
  // TODO: substituir por SQLite — buscar clientes do banco em vez do mock
  Iterable<Map<String, dynamic>> _filtrar(String texto) {
    final busca = texto.toLowerCase();
    return DadosMock().clientesMock.where((c) {
      return c['nome'].toString().toLowerCase().contains(busca) ||
          c['cpf'].toString().toLowerCase().contains(busca) ||
          c['telefone'].toString().toLowerCase().contains(busca);
    });
  }

  void _confirmar(Map<String, dynamic> cliente) {
    if (_selecionado) return;
    _selecionado = true;
    widget.onClienteSelecionado(cliente);
    Navigator.pop(context);
  }

  /// Constrói o formulário de busca com Autocomplete.
  /// Ao selecionar um cliente (mouse, seta+Enter ou Enter direto), chama
  /// [onClienteSelecionado] e fecha o popup.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
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
              return _filtrar(valorDigitado.text);
            },
            displayStringForOption: (Map<String, dynamic> c) => c['nome'],
            // Seleção via clique ou seta+Enter
            onSelected: _confirmar,
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
                // Necessário para que seta+Enter acione onSelected acima
                onEditingComplete: onEditingComplete,
                // Seleção via Enter direto (sem navegar na lista): pega o primeiro resultado
                onSubmitted: (texto) {
                  final matches = _filtrar(texto).toList();
                  if (matches.isNotEmpty) _confirmar(matches.first);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
