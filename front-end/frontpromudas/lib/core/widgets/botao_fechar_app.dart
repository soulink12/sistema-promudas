import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/cores_semanticas.dart';
import 'dialog_confirmacao.dart';

/// Botão para encerrar o app, posicionado no canto superior direito.
/// Necessário porque a janela roda em modo quiosque (sem borda/barra de
/// título do Windows — ver windows/runner/win32_window.cpp), então não há
/// mais botão de fechar nativo.
class BotaoFecharApp extends StatelessWidget {
  const BotaoFecharApp({super.key});

  Future<void> _fechar(BuildContext context) async {
    final confirmar = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Fechar o sistema',
      mensagem: 'Tem certeza que deseja fechar o Sistema Promudas?',
      textoConfirmar: 'Fechar',
    );
    if (confirmar) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: IconButton(
        icon: const Icon(Icons.close),
        color: CoresSemanticas.erro,
        tooltip: 'Fechar programa',
        onPressed: () => _fechar(context),
      ),
    );
  }
}
