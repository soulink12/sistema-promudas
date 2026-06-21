// Infra compartilhada dos testes e2e de UI (integration_test).
// Helpers de bombeamento robustos (sem pumpAndSettle, que trava com spinners),
// login, navegação por drawer, fake do file_picker e semeadura de dados via API.
//
// ⚠️ Os testes dirigem o app Windows real contra o backend (localhost:6072) +
// banco de TESTE. Semeiam dados via API e limpam no fim (soft-delete).

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:frontpromudas/main.dart' as app;
import 'package:frontpromudas/core/services/api_service.dart';

const emailTeste = String.fromEnvironment(
  'TEST_USER_EMAIL',
  defaultValue: 'lucasgsalbuquerque@gmail.com',
);
const senhaTeste = String.fromEnvironment(
  'TEST_USER_SENHA',
  defaultValue: '987741',
);

/// Fake do FilePicker: troca o diálogo nativo de "Salvar" por um caminho fixo,
/// para o teste rodar sem abrir janela do SO. O download dos bytes e a gravação
/// (em PdfDownloadService) continuam reais.
class FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  final String caminhoDestino;
  FakeFilePicker(this.caminhoDestino);

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

/// Bombeia frames até [finder] aparecer (ou estourar o timeout). Mais robusto
/// que pumpAndSettle quando há spinners na tela (que nunca "assentam").
Future<void> bombearAte(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
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
Future<void> bombearAteSumir(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final fim = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fim)) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timeout esperando o widget sumir: $finder');
}

/// Bombeia frames até o [arquivo] existir no disco (gravado de forma assíncrona).
Future<void> aguardarArquivo(
  WidgetTester tester,
  File arquivo, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final fim = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fim)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (arquivo.existsSync() && await arquivo.length() > 0) return;
  }
  throw TestFailure('Timeout esperando o arquivo: ${arquivo.path}');
}

/// Traz a linha [tile] para o centro do viewport. O `scrollUntilVisible` para
/// com a linha colada no rodapé, onde o FloatingActionButton cobre os botões da
/// trailing (editar/switch) → o `tap` erra. Centralizar evita o FAB e a AppBar.
Future<void> centralizarLinha(WidgetTester tester, Finder tile) async {
  await tester.scrollUntilVisible(tile, 100,
      scrollable: find.byType(Scrollable).first);
  // `duration` precisa ser zero: com animação, o `await` trava (o relógio do
  // teste não avança sem `pump`, e estamos bloqueados aqui). Salto instantâneo.
  await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Abre um DropdownButtonFormField e seleciona a opção [texto]. Faz retry porque
/// as opções podem carregar de forma assíncrona (ex.: locais de entrega).
Future<void> selecionarDropdown(
  WidgetTester tester,
  Finder dropdown,
  String texto, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final fim = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(fim)) {
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 500));
    final opcao = find.text(texto).last;
    if (opcao.evaluate().isNotEmpty) {
      await tester.tap(opcao);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  throw TestFailure('Timeout selecionando "$texto" no dropdown');
}

/// Sobe o app real e espera a tela de login.
Future<void> iniciarApp(WidgetTester tester) async {
  app.main();
  await bombearAte(tester, find.byType(TextFormField));
}

/// Faz login pela UI e espera chegar na tela de módulos (cards PDV / Entregas).
Future<void> fazerLogin(
  WidgetTester tester, {
  String email = emailTeste,
  String senha = senhaTeste,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), senha);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await bombearAte(tester, find.text('Entregas'));
}

/// Abre o drawer (tocando o botão de menu do AppBar) e toca um item pelo texto.
Future<void> abrirItemDrawer(WidgetTester tester, String item) async {
  final menu = find.byTooltip('Open navigation menu');
  await bombearAte(tester, menu);
  await tester.tap(menu);
  await bombearAte(tester, find.text(item));
  await tester.tap(find.text(item));
}

/// Semeia dados de cenário via API (após o login da UI ter setado o token) e
/// registra os ids para limpeza no fim. `limpar()` usa DELETE da API
/// (soft-delete — deixa linhas `ativo=false`, inofensivas no banco de teste).
class Semear {
  final _produtos = <int>[];
  final _clientes = <int>[];
  final _pedidos = <int>[];
  final _formas = <int>[];

  static String _marca(String p) =>
      '__e2e_ui_${p}_${DateTime.now().microsecondsSinceEpoch}';

  Future<int> produto({String? nome, num preco = 50}) async {
    final r = await ApiService.dio.post('/produtos',
        data: {'nome': nome ?? _marca('prod'), 'preco': preco});
    final id = r.data['id'] as int;
    _produtos.add(id);
    return id;
  }

  Future<int> cliente({String? nome}) async {
    final r = await ApiService.dio
        .post('/clientes', data: {'nome': nome ?? _marca('cli')});
    final id = r.data['id'] as int;
    _clientes.add(id);
    return id;
  }

  Future<int> pedido({
    required int clienteId,
    required List<Map<String, dynamic>> itens,
    num? valorTotal,
  }) async {
    final total = valorTotal ??
        itens.fold<num>(
            0, (s, i) => s + (i['valor_unitario'] as num) * (i['quantidade'] as num));
    final r = await ApiService.dio.post('/pedidos', data: {
      'cliente_id': clienteId,
      'valor_total': total,
      'itens': itens,
    });
    final id = r.data['data']['id'] as int;
    _pedidos.add(id);
    return id;
  }

  /// Registra um pagamento no pedido (limpo junto com o pedido por cascade
  /// no soft-delete — a linha de pagamento em si permanece, inofensiva).
  Future<int> pagar({
    required int pedidoId,
    required num valor,
    String forma = 'Dinheiro',
  }) async {
    // O backend (Prisma Timestamp) rejeita o ISO do Dart (microssegundos, sem
    // "Z") com 500. Emitimos milissegundos + "Z", como o `new Date().toISOString()`.
    final agora = DateTime.fromMillisecondsSinceEpoch(
            DateTime.now().millisecondsSinceEpoch,
            isUtc: true)
        .toIso8601String();
    final r = await ApiService.dio.post('/pagamentos', data: {
      'pedido_id': pedidoId,
      'valor_pago': valor,
      'forma_pagamento': forma,
      'data_pagamento': agora,
    });
    return r.data['id'] as int;
  }

  void registrarPedido(int id) => _pedidos.add(id);
  void registrarProduto(int id) => _produtos.add(id);
  void registrarCliente(int id) => _clientes.add(id);
  void registrarForma(int id) => _formas.add(id);

  Future<void> limpar() async {
    for (final id in _pedidos) {
      try { await ApiService.dio.delete('/pedidos/$id'); } catch (_) {}
    }
    for (final id in _produtos) {
      try { await ApiService.dio.delete('/produtos/$id'); } catch (_) {}
    }
    for (final id in _clientes) {
      try { await ApiService.dio.delete('/clientes/$id'); } catch (_) {}
    }
    for (final id in _formas) {
      try { await ApiService.dio.delete('/formas-pagamento/$id'); } catch (_) {}
    }
  }
}
