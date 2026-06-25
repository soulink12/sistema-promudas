import 'package:flutter/material.dart';
import '../services/cliente_service.dart';

/// Autocomplete de clientes reutilizável.
/// Pesquisa os clientes diretamente no backend conforme o usuário digita
/// (busca server-side por nome, CPF ou telefone — alcança TODOS os clientes).
/// [onSelecionado] é chamado com o cliente escolhido.
class CampoBuscaCliente extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelecionado;
  final String labelText;
  final String hintText;
  final bool autofocus;

  const CampoBuscaCliente({
    super.key,
    required this.onSelecionado,
    this.labelText = '',
    this.hintText = 'Digite nome, CPF ou telefone',
    this.autofocus = false,
  });

  @override
  State<CampoBuscaCliente> createState() => _CampoBuscaClienteState();
}

class _CampoBuscaClienteState extends State<CampoBuscaCliente> {
  // Guarda a última digitação para o debounce descartar buscas obsoletas.
  String _ultimaDigitacao = '';

  /// Pesquisa clientes no backend. Faz debounce de 250ms: se o usuário continuar
  /// digitando, a chamada anterior é descartada e só a mais recente vai à API.
  Future<Iterable<Map<String, dynamic>>> _buscar(String texto) async {
    final busca = texto.trim();
    if (busca.isEmpty) return const Iterable.empty();

    _ultimaDigitacao = busca;
    await Future.delayed(const Duration(milliseconds: 250));
    if (busca != _ultimaDigitacao) return const Iterable.empty();

    try {
      return await ClienteService().listar(busca: busca);
    } catch (_) {
      return const Iterable.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (valor) => _buscar(valor.text),
      displayStringForOption: (c) => c['nome'] as String,
      onSelected: widget.onSelecionado,
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            labelText: widget.labelText.isNotEmpty ? widget.labelText : null,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
          ),
          onEditingComplete: onEditingComplete,
          onSubmitted: (texto) async {
            final matches = (await _buscar(texto)).toList();
            if (matches.isNotEmpty) widget.onSelecionado(matches.first);
          },
        );
      },
    );
  }
}
