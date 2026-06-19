import 'package:flutter/material.dart';
import '../services/cliente_service.dart';
import '../theme/cores_semanticas.dart';

/// Autocomplete de clientes reutilizável.
/// Carrega a lista de clientes da API e exibe sugestões ao digitar.
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
  List<Map<String, dynamic>> _clientes = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await ClienteService().listar();
      setState(() {
        _clientes = lista;
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar os clientes.';
        _carregando = false;
      });
    }
  }

  Iterable<Map<String, dynamic>> _filtrar(String texto) {
    final busca = texto.toLowerCase();
    return _clientes.where((c) =>
        c['nome'].toString().toLowerCase().contains(busca) ||
        c['cpf'].toString().toLowerCase().contains(busca) ||
        c['telefone'].toString().toLowerCase().contains(busca));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const LinearProgressIndicator();
    }

    if (_erro != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: CoresSemanticas.erro, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_erro!, style: const TextStyle(color: CoresSemanticas.erro, fontSize: 13))),
          TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
        ],
      );
    }

    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (valor) {
        if (valor.text.isEmpty) return const Iterable.empty();
        return _filtrar(valor.text);
      },
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
          onSubmitted: (texto) {
            final matches = _filtrar(texto).toList();
            if (matches.isNotEmpty) widget.onSelecionado(matches.first);
          },
        );
      },
    );
  }
}
