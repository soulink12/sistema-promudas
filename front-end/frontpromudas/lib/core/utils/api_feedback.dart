import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Helpers de feedback de chamadas à API, reutilizados em todo o app.
///
/// Centralizam o que antes estava duplicado como `_extrairErro` / `_mostrarErro`
/// em telas individuais.

/// Extrai a mensagem de erro padrão da API (chave `erro`, em português) de um
/// erro do Dio. Cai em [fallback] quando não há resposta estruturada.
String extrairErroApi(Object e, [String fallback = 'Ocorreu um erro. Tente novamente.']) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['erro'] is String) return data['erro'] as String;
  }
  return fallback;
}

/// Mostra um SnackBar de erro (cor de erro do tema).
void mostrarErro(BuildContext context, String mensagem) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagem),
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Mostra um SnackBar de sucesso (cor primária do tema).
void mostrarSucesso(BuildContext context, String mensagem) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagem),
      backgroundColor: Theme.of(context).colorScheme.primary,
    ),
  );
}
