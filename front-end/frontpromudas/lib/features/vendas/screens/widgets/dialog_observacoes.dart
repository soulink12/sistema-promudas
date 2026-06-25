import 'package:flutter/material.dart';

/// Diálogo para adicionar ou editar as observações do pedido.
/// Retorna o texto digitado (já com trim) ao salvar, ou `null` se cancelado.
class DialogObservacoes extends StatefulWidget {
  // Observações já existentes (modo edição) — pré-preenche o campo
  final String? observacoesAtuais;

  const DialogObservacoes({super.key, this.observacoesAtuais});

  @override
  State<DialogObservacoes> createState() => _DialogObservacoesState();
}

class _DialogObservacoesState extends State<DialogObservacoes> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.observacoesAtuais ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Observações do pedido'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Digite observações sobre o pedido',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
