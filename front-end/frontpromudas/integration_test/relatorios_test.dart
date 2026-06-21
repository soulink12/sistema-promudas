// e2e de UI — Parte 4: Relatórios (Pagamentos e Pedidos) + PDF.
// Login → PDV → drawer "Relatórios" → "Pagamentos" → Gerar Relatório → PDF;
// volta → "Pedidos" → Gerar Relatório → PDF. Valida que cada PDF começa com %PDF-.
// Ver _support.dart para a infra compartilhada.
//
// Rodar: flutter test integration_test/relatorios_test.dart -d windows
// Pré-requisito: backend de pé na 6072 + banco de teste.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:file_picker/file_picker.dart';

import '_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gera os relatórios de pagamentos e pedidos em PDF', (tester) async {
    final pdfPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}e2e_relatorio.pdf';
    final pdfFile = File(pdfPath);
    if (pdfFile.existsSync()) pdfFile.deleteSync();
    FilePicker.platform = FakeFilePicker(pdfPath);

    final semear = Semear();
    addTearDown(() async => semear.limpar());

    // 1. App + login.
    await iniciarApp(tester);
    await fazerLogin(tester);

    // 2. Entra no PDV (de onde o drawer fica disponível).
    await tester.tap(find.text('PDV'));
    final campoBusca = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Nome, Cód. ou QTDxID (ex: 10x1)',
    );
    await bombearAte(tester, campoBusca);

    // 3. Semeia um pedido pago para os relatórios terem dados.
    final produtoId = await semear.produto(preco: 50);
    final pedidoId = await semear.pedido(
      clienteId: 1,
      itens: [{'produto_id': produtoId, 'quantidade': 2, 'valor_unitario': 50}],
    );
    await semear.pagar(pedidoId: pedidoId, valor: 100);

    // 4. Drawer → Relatórios → card "Pagamentos".
    await abrirItemDrawer(tester, 'Relatórios');
    await bombearAte(tester, find.text('Pagamentos'));
    await tester.tap(find.text('Pagamentos'));

    // 5. Gera o relatório e exporta o PDF.
    await bombearAte(tester, find.widgetWithText(FilledButton, 'Gerar Relatório'));
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar Relatório'));
    await bombearAte(tester, find.text('TOTAL GERAL'));

    final btnPdfPag = find.byTooltip('Exportar PDF');
    await bombearAte(tester, btnPdfPag);
    await tester.tap(btnPdfPag);
    await aguardarArquivo(tester, pdfFile);
    var bytes = await pdfFile.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
        reason: 'relatório de pagamentos não é PDF');

    // 6. Volta ao hub e abre o relatório de "Pedidos".
    pdfFile.deleteSync();
    await tester.tap(find.byType(BackButton));
    await bombearAte(tester, find.text('Pedidos'));
    await tester.tap(find.text('Pedidos'));

    // 7. Gera o relatório de pedidos e exporta o PDF.
    await bombearAte(tester, find.widgetWithText(FilledButton, 'Gerar Relatório'));
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar Relatório'));
    final btnPdfPed = find.byTooltip('Exportar PDF');
    await bombearAte(tester, btnPdfPed);
    await tester.ensureVisible(btnPdfPed);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(btnPdfPed);
    await aguardarArquivo(tester, pdfFile);
    bytes = await pdfFile.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
        reason: 'relatório de pedidos não é PDF');
  });
}
