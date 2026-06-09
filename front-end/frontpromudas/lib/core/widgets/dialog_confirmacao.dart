import 'package:flutter/material.dart';

Future<bool> mostrarDialogConfirmacao({
  required BuildContext context,
  required String titulo,
  required String mensagem,
  String textoCancelar = 'Cancelar',
  String textoConfirmar = 'Confirmar',
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(textoCancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return resultado == true;
}
