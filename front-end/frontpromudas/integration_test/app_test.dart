// e2e de UI — fluxo COMPLETO de uma venda no PDV (login → PDV → carrinho →
// pagamento → recibo PDF). Ver _support.dart para a infra compartilhada.
//
// Rodar: flutter test integration_test/app_test.dart -d windows
// Pré-requisito: backend de pé na 6072 + banco de teste.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:file_picker/file_picker.dart';

import 'package:frontpromudas/core/services/api_service.dart';
import '_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('venda completa no PDV gera o PDF do recibo', (tester) async {
    final pdfPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}e2e_pedido_ui.pdf';
    final pdfFile = File(pdfPath);
    if (pdfFile.existsSync()) pdfFile.deleteSync();
    FilePicker.platform = FakeFilePicker(pdfPath);

    final semear = Semear();
    int? pedidoId; // capturado do POST /pedidos feito pela UI
    addTearDown(() async => semear.limpar());

    // 1. App + login (chega na tela de módulos).
    await iniciarApp(tester);
    await fazerLogin(tester);
    expect(find.text('PDV'), findsOneWidget);

    // 2. Produto descartável + interceptor para capturar o pedido criado pela UI.
    ApiService.dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final req = response.requestOptions;
        if (req.method == 'POST' && req.path == '/pedidos') {
          pedidoId = response.data?['data']?['id'] as int?;
          if (pedidoId != null) semear.registrarPedido(pedidoId!);
        }
        handler.next(response);
      },
    ));
    final nomeProduto = '__e2e_ui_venda_${DateTime.now().millisecondsSinceEpoch}';
    final produtoId = await semear.produto(nome: nomeProduto, preco: 50);

    // 3. Entra no PDV.
    await tester.tap(find.text('PDV'));
    final campoBusca = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Nome, Cód. ou QTDxID (ex: 10x1)',
    );
    await bombearAte(tester, campoBusca);

    // 4. Adiciona o produto pelo código (retry até o item aparecer no carrinho).
    var adicionado = false;
    final fimAdd = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(fimAdd)) {
      await tester.enterText(campoBusca, '$produtoId');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
      if (find.text(nomeProduto).evaluate().isNotEmpty) {
        adicionado = true;
        break;
      }
    }
    expect(adicionado, isTrue, reason: 'produto não foi adicionado ao carrinho');

    // 5. Finaliza o pedido → modal de pagamento → forma padrão → finalizar.
    await tester.tap(find.textContaining('Finalizar Pedido'));
    await bombearAte(tester, find.text('Pagamento do Pedido'));
    await bombearAteSumir(tester, find.byType(LinearProgressIndicator));

    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar Pagamento'));

    // 6. App cria pedido + pagamento e baixa o PDF.
    await aguardarArquivo(tester, pdfFile);

    // 7. Validações.
    final bytes = await pdfFile.readAsBytes();
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    expect(pedidoId, isNotNull, reason: 'não capturou o id do pedido criado');
    final ped = await ApiService.dio.get('/pedidos/$pedidoId');
    expect(ped.data['status_pagamento'], 'Pago');

    // 8. Abre o PDF para inspeção visual.
    try {
      await Process.start('cmd', ['/c', 'start', '', pdfPath],
          mode: ProcessStartMode.detached);
    } catch (_) {}
  });
}
