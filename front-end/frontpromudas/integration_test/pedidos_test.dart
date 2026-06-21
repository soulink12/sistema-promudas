// e2e de UI — Parte 2: consulta de Pedidos + registrar pagamento + PDF.
// Login → PDV → drawer "Consulta" → "Pedidos" → detalhes → "Registrar Pagamento"
// → recibo PDF + status Pago; depois "Emitir PDF" gera o recibo de novo.
// Ver _support.dart para a infra compartilhada.
//
// Rodar: flutter test integration_test/pedidos_test.dart -d windows
// Pré-requisito: backend de pé na 6072 + banco de teste.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:file_picker/file_picker.dart';

import 'package:frontpromudas/core/services/api_service.dart';
import '_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registra pagamento na consulta de pedidos e gera o PDF', (tester) async {
    final pdfPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}e2e_pedido_consulta.pdf';
    final pdfFile = File(pdfPath);
    if (pdfFile.existsSync()) pdfFile.deleteSync();
    FilePicker.platform = FakeFilePicker(pdfPath);

    final semear = Semear();
    addTearDown(() async => semear.limpar());

    // 1. App + login (tela de módulos).
    await iniciarApp(tester);
    await fazerLogin(tester);

    // 2. Semeia produto + pedido (Consumidor id=1) total 100, Pendente.
    final produtoId = await semear.produto(preco: 50);
    final pedidoId = await semear.pedido(
      clienteId: 1,
      itens: [{'produto_id': produtoId, 'quantidade': 2, 'valor_unitario': 50}],
    );

    // 3. Entra no PDV.
    await tester.tap(find.text('PDV'));
    final campoBusca = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Nome, Cód. ou QTDxID (ex: 10x1)',
    );
    await bombearAte(tester, campoBusca);

    // 4. Drawer → Consulta → card "Pedidos".
    await abrirItemDrawer(tester, 'Consulta');
    await bombearAte(tester, find.text('Pedidos'));
    await tester.tap(find.text('Pedidos'));

    // 5. Abre o pedido semeado na lista.
    final cardPedido = find.textContaining('Pedido #$pedidoId ·');
    await bombearAte(tester, cardPedido);
    await tester.tap(cardPedido);

    // 6. Detalhes → "Registrar Pagamento" → modal.
    final btnRegistrarPagamento =
        find.widgetWithText(FilledButton, 'Registrar Pagamento');
    await bombearAte(tester, btnRegistrarPagamento);
    await tester.ensureVisible(btnRegistrarPagamento); // botão fica abaixo da dobra
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(btnRegistrarPagamento);

    await bombearAte(tester, find.text('Pagamento do Pedido'));
    await bombearAte(tester, find.text('Forma de pagamento')); // formas carregadas

    // Forma padrão (Dinheiro) + valor já pré-preenchido com o total.
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar Pagamento'));

    // 7. App registra o pagamento e baixa o recibo PDF.
    await aguardarArquivo(tester, pdfFile);
    var bytes = await pdfFile.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: 'recibo não é PDF');

    // Status do pedido virou Pago.
    final ped = await ApiService.dio.get('/pedidos/$pedidoId');
    expect(ped.data['status_pagamento'], 'Pago');

    // 8. Botão "Emitir PDF" gera o recibo novamente.
    pdfFile.deleteSync();
    final btnEmitir = find.widgetWithText(OutlinedButton, 'Emitir PDF');
    await bombearAte(tester, btnEmitir);
    await tester.ensureVisible(btnEmitir);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(btnEmitir);
    await aguardarArquivo(tester, pdfFile);
    bytes = await pdfFile.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: 'Emitir PDF não gerou PDF');
  });
}
