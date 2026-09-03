import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/dialog_confirmacao.dart';
import 'api_feedback.dart';

/// Confirma com o usuário e envia um documento (pedido/orçamento) por e-mail
/// via [caminho] (ex.: '/pedidos/12/enviar-email'). Mostra o snackbar de
/// sucesso/erro. Reutilizado no preview do PDF e na tela de detalhes do
/// orçamento. Retorna `true` se o e-mail foi enviado; `false` se o usuário
/// cancelou a confirmação ou o envio falhou (o erro já foi mostrado).
Future<bool> enviarDocumentoPorEmail({
  required BuildContext context,
  required String caminho,
  required String nomeDocumento,
  required String email,
}) async {
  final confirmado = await mostrarDialogConfirmacao(
    context: context,
    titulo: 'Enviar por e-mail',
    mensagem: 'Enviar $nomeDocumento por e-mail para $email?',
    textoConfirmar: 'Enviar',
  );
  if (!confirmado || !context.mounted) return false;

  try {
    await ApiService.dio.post(caminho);
    if (context.mounted) mostrarSucesso(context, 'E-mail enviado com sucesso!');
    return true;
  } catch (e) {
    if (context.mounted) {
      mostrarErro(context, extrairErroApi(e, 'Não foi possível enviar o e-mail.'));
    }
    return false;
  }
}
