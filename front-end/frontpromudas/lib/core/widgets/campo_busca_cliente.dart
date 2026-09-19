import 'package:flutter/material.dart';
import '../services/cliente_service.dart';
import '../utils/formatadores.dart';

/// Autocomplete de clientes reutilizável.
/// Pesquisa os clientes diretamente no backend conforme o usuário digita
/// (busca server-side por nome, CPF ou telefone — alcança TODOS os clientes).
/// [onSelecionado] é chamado com o cliente escolhido.
///
/// [onTextoNumerico] é opcional: quando informado, texto que comece com dígito
/// ou "#" é tratado como busca alternativa (ex.: número do pedido) em vez de
/// nome de cliente — não dispara busca de clientes nem mostra sugestões, só
/// repassa o texto (com debounce) para o callback.
class CampoBuscaCliente extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelecionado;
  final String labelText;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onTextoNumerico;
  // Regex usado para decidir se o texto digitado é "número" (em vez de nome
  // de cliente). Padrão: começa com "#" ou dígito (número de pedido). Telas
  // com um prefixo de letra no número (ex.: orçamento "O26-3") podem passar
  // um regex próprio, pra não confundir com nome de cliente começando com
  // essa letra.
  final RegExp? regexNumerico;

  const CampoBuscaCliente({
    super.key,
    required this.onSelecionado,
    this.labelText = '',
    this.hintText = 'Digite nome, CPF ou telefone',
    this.autofocus = false,
    this.onTextoNumerico,
    this.regexNumerico,
  });

  @override
  State<CampoBuscaCliente> createState() => _CampoBuscaClienteState();
}

class _CampoBuscaClienteState extends State<CampoBuscaCliente> {
  // Guarda a última digitação para o debounce descartar buscas obsoletas.
  String _ultimaDigitacao = '';
  bool _modoNumero = false;

  /// Pesquisa clientes no backend. Faz debounce de 250ms: se o usuário continuar
  /// digitando, a chamada anterior é descartada e só a mais recente vai à API.
  Future<Iterable<Map<String, dynamic>>> _buscar(String texto) async {
    final busca = texto.trim();
    if (busca.isEmpty || _modoNumero) return const Iterable.empty();

    _ultimaDigitacao = busca;
    await Future.delayed(const Duration(milliseconds: 250));
    if (busca != _ultimaDigitacao) return const Iterable.empty();

    try {
      return await ClienteService().listar(busca: busca);
    } catch (_) {
      return const Iterable.empty();
    }
  }

  // Detecta se o texto atual deve ser tratado como busca alternativa (número)
  // em vez de nome de cliente, e repassa (com debounce) para o callback.
  void _aoDigitar(String texto) {
    if (widget.onTextoNumerico == null) return;
    final busca = texto.trim();
    final regex = widget.regexNumerico ?? RegExp(r'^[#\d]');
    final numerico = busca.isNotEmpty && regex.hasMatch(busca);
    setState(() => _modoNumero = numerico);

    _ultimaDigitacao = busca;
    if (!numerico) {
      // Campo vazio ou texto que deixou de ser número (ex.: apagou até sobrar
      // só o prefixo "O") — limpa o filtro por número, senão a lista continua
      // presa no último resultado numérico enquanto o campo já virou busca
      // por nome de cliente.
      widget.onTextoNumerico!('');
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (busca == _ultimaDigitacao) widget.onTextoNumerico!(busca);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (valor) => _buscar(valor.text),
      displayStringForOption: (c) => capitalizarNome(c['nome'] as String? ?? ''),
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
          onChanged: _aoDigitar,
          onEditingComplete: onEditingComplete,
          onSubmitted: (texto) async {
            if (_modoNumero) return;
            final matches = (await _buscar(texto)).toList();
            if (matches.isNotEmpty) widget.onSelecionado(matches.first);
          },
        );
      },
    );
  }
}
