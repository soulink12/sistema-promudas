// Teste e2e de UI (integration_test) — fluxo COMPLETO de uma venda no PDV.
//
// Dirige o app Windows real contra o backend rodando (localhost:6072) e o banco
// de TESTE: login → escolhe módulo PDV → adiciona um produto descartável ao
// carrinho → finaliza o pagamento → o app cria o pedido + pagamento via API e
// baixa o PDF do recibo. Ao final, valida o PDF e o abre para inspeção visual.
//
// ⚠️ Pré-requisitos: backend de pé na 6072 apontando para o banco de teste.
// ⚠️ Escreve no banco (cria 1 produto + 1 pedido + 1 pagamento). Limpeza no fim
//    via soft-delete (DELETE /produtos/:id e /pedidos/:id deixam `ativo=false`);
//    o pagamento permanece como linha (a API não tem hard-delete) — ok no banco
//    de teste. O diálogo nativo de salvar é trocado por um fake (não trava).
//
// Rodar: flutter test integration_test/app_test.dart -d windows
// Credenciais via --dart-define=TEST_USER_EMAIL=... / TEST_USER_SENHA=...

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:frontpromudas/main.dart' as app;
import 'package:frontpromudas/core/services/api_service.dart';

/// Substitui o diálogo nativo de "Salvar arquivo" por um caminho fixo, para o
/// teste rodar sem abrir janela do SO. O download dos bytes e a gravação do
/// arquivo (em PdfDownloadService) continuam reais.
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  final String caminhoDestino;
  _FakeFilePicker(this.caminhoDestino);

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async =>
      caminhoDestino;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'TEST_USER_EMAIL',
    defaultValue: 'lucasgsalbuquerque@gmail.com',
  );
  const senha = String.fromEnvironment(
    'TEST_USER_SENHA',
    defaultValue: '987741',
  );

  testWidgets('venda completa no PDV gera o PDF do recibo', (tester) async {
    // PDF de saída em caminho fixo (apagado antes de começar, mantido no fim
    // para você abrir e conferir).
    final pdfPath = '${Directory.systemTemp.path}${Platform.pathSeparator}e2e_pedido_ui.pdf';
    final pdfFile = File(pdfPath);
    if (pdfFile.existsSync()) pdfFile.deleteSync();
    FilePicker.platform = _FakeFilePicker(pdfPath);

    int? produtoId;
    int? pedidoId; // capturado do POST /pedidos para validar e limpar

    // Limpeza garantida mesmo se o teste falhar no meio.
    addTearDown(() async {
      try {
        if (pedidoId != null) await ApiService.dio.delete('/pedidos/$pedidoId');
      } catch (_) {}
      try {
        if (produtoId != null) await ApiService.dio.delete('/produtos/$produtoId');
      } catch (_) {}
    });

    // ── 1. Sobe o app ────────────────────────────────────────────────────────
    app.main();
    await _aguardar(tester, find.byType(TextFormField));

    // ── 2. Login ─────────────────────────────────────────────────────────────
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), senha);
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));

    // Chega na tela de módulos (PDV / Entregas).
    await _aguardar(tester, find.text('Entregas'));
    expect(find.text('PDV'), findsOneWidget);

    // ── 3. Cria um produto descartável via API (já autenticado) ──────────────
    // Interceptor para capturar o id do pedido que a UI vai criar.
    ApiService.dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final req = response.requestOptions;
        if (req.method == 'POST' && req.path == '/pedidos') {
          pedidoId = response.data?['data']?['id'] as int?;
        }
        handler.next(response);
      },
    ));

    final nomeProduto = '__e2e_ui_${DateTime.now().millisecondsSinceEpoch}';
    final respProduto = await ApiService.dio.post(
      '/produtos',
      data: {'nome': nomeProduto, 'preco': 50},
    );
    produtoId = respProduto.data['id'] as int;

    // ── 4. Entra no PDV ──────────────────────────────────────────────────────
    await tester.tap(find.text('PDV'));

    // Aguarda o campo de busca do rodapé aparecer (PDV montado).
    final campoBusca = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Nome, Cód. ou QTDxID (ex: 10x1)',
    );
    await _aguardar(tester, campoBusca);

    // ── 5. Adiciona o produto pelo código no rodapé ──────────────────────────
    // Os produtos carregam de forma assíncrona; tenta adicionar (digitar o
    // código + Enter) em laço até o item aparecer no carrinho — assim não
    // depende do instante exato em que a lista terminou de carregar.
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
    expect(adicionado, isTrue,
        reason: 'produto não foi adicionado ao carrinho (lista carregou?)');
    expect(find.textContaining('Total do Pedido'), findsOneWidget);

    // ── 6. Finaliza o pedido → abre o modal de pagamento ─────────────────────
    await tester.tap(find.textContaining('Finalizar Pedido'));
    // Modal carrega formas + contas (some o progress bar interno).
    await _aguardar(tester, find.text('Pagamento do Pedido'));
    await _aguardarSumir(tester, find.byType(LinearProgressIndicator));

    // Usa a forma de pagamento padrão (1ª da lista = Dinheiro no seed) com o
    // valor já pré-preenchido com o total. Adiciona a parcela e finaliza.
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pump(const Duration(milliseconds: 300));

    final finalizarPagamento =
        find.widgetWithText(FilledButton, 'Finalizar Pagamento');
    expect(finalizarPagamento, findsOneWidget);
    await tester.tap(finalizarPagamento);

    // ── 7. App cria pedido + pagamento e baixa o PDF ─────────────────────────
    await _aguardarArquivo(tester, pdfFile);

    // ── 8. Validações ────────────────────────────────────────────────────────
    expect(pdfFile.existsSync(), isTrue, reason: 'PDF não foi gravado');
    final bytes = await pdfFile.readAsBytes();
    expect(bytes.length, greaterThan(500), reason: 'PDF muito pequeno/vazio');
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
        reason: 'arquivo gerado não é um PDF válido');

    // O pedido foi criado e quitado (pagamento real = Dinheiro).
    expect(pedidoId, isNotNull, reason: 'não capturou o id do pedido criado');
    final ped = await ApiService.dio.get('/pedidos/$pedidoId');
    expect(ped.data['status_pagamento'], 'Pago');

    // ── 9. Abre o PDF para inspeção visual ───────────────────────────────────
    try {
      await Process.start(
        'cmd',
        ['/c', 'start', '', pdfPath],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}

    // ignore: avoid_print
    print('✓ e2e UI concluído. PDF salvo em: $pdfPath');
  });
}

/// Bombeia frames até [finder] aparecer (ou estourar o timeout). Mais robusto
/// que pumpAndSettle quando há spinners (Circular/LinearProgressIndicator) na
/// tela, que nunca "assentam".
Future<void> _aguardar(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  bool opcional = false,
}) async {
  final fim = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fim)) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isNotEmpty) return;
  }
  if (!opcional) {
    throw TestFailure('Timeout esperando o widget aparecer: $finder');
  }
}

/// Bombeia frames até [finder] desaparecer (ou estourar o timeout).
Future<void> _aguardarSumir(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final fim = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fim)) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timeout esperando o widget sumir: $finder');
}

/// Bombeia frames até o [arquivo] existir no disco (ou estourar o timeout).
/// O PDF é gravado de forma assíncrona após o POST do pedido/pagamento.
Future<void> _aguardarArquivo(
  WidgetTester tester,
  File arquivo, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fim = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fim)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (arquivo.existsSync() && await arquivo.length() > 0) return;
  }
  throw TestFailure('Timeout esperando o PDF ser gravado em: ${arquivo.path}');
}
