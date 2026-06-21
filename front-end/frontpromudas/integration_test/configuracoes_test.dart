// e2e de UI — Parte 5: Configurações (Produtos e Formas de Pagamento).
// Login → PDV → drawer "Configurações" → "Produtos" (cria → edita preço →
// desativa) → volta → "Formas de Pagamento" (cria → desativa). Valida via API.
// Ver _support.dart para a infra compartilhada.
//
// Rodar: flutter test integration_test/configuracoes_test.dart -d windows
// Pré-requisito: backend de pé na 6072 + banco de teste.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontpromudas/core/services/api_service.dart';
import '_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cria, edita e desativa produto e forma de pagamento',
      (tester) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final nomeProduto = '__e2e_ui_prod_$ts';
    final nomeForma = '__e2e_ui_forma_$ts';
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

    // ── PRODUTOS ────────────────────────────────────────────────────────────
    // 3. Configurações → "Produtos".
    await abrirItemDrawer(tester, 'Configurações');
    await bombearAte(tester, find.text('Produtos'));
    await tester.tap(find.text('Produtos'));
    await bombearAte(tester, find.byTooltip('Novo produto'));

    // 4. FAB → dialog: cria o produto (nome + preço).
    await tester.tap(find.byTooltip('Novo produto'));
    await bombearAte(tester, find.text('Novo produto'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome *'), nomeProduto);
    await tester.enterText(find.widgetWithText(TextFormField, 'Preço *'), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await bombearAteSumir(tester, find.text('Novo produto'));

    // Descobre o id criado (lista ordenada por nome) p/ limpar no fim.
    final listaProd = await ApiService.dio.get('/produtos');
    final prod = (listaProd.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .firstWhere((p) => p['nome'] == nomeProduto);
    final produtoId = prod['id'] as int;
    semear.registrarProduto(produtoId);

    // 5. Acha a linha do produto, edita o preço.
    final tileProd = find.widgetWithText(ListTile, nomeProduto);
    await centralizarLinha(tester, tileProd);
    await tester.tap(
        find.descendant(of: tileProd, matching: find.byTooltip('Editar')));
    await bombearAte(tester, find.text('Editar produto'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Preço *'), '25');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await bombearAteSumir(tester, find.text('Editar produto'));

    // 6. Desativa o produto pelo Switch da linha.
    await centralizarLinha(tester, tileProd);
    await tester
        .tap(find.descendant(of: tileProd, matching: find.byType(Switch)));
    await tester.pump(const Duration(milliseconds: 600));

    // Valida no backend: preço atualizado e produto inativo.
    final prodApi = (await ApiService.dio.get('/produtos')).data as List;
    final prodAtual = prodApi
        .map((e) => Map<String, dynamic>.from(e as Map))
        .firstWhere((p) => p['id'] == produtoId);
    expect(double.parse(prodAtual['preco'].toString()), 25);
    expect(prodAtual['ativo'], false);

    // ── FORMAS DE PAGAMENTO ───────────────────────────────────────────────────
    // 7. Volta às Configurações e abre "Formas de Pagamento".
    await tester.tap(find.byType(BackButton));
    await bombearAte(tester, find.text('Formas de Pagamento'));
    await tester.tap(find.text('Formas de Pagamento'));
    await bombearAte(tester, find.byTooltip('Nova forma de pagamento'));

    // 8. FAB → dialog: cria a forma (só o nome).
    await tester.tap(find.byTooltip('Nova forma de pagamento'));
    await bombearAte(tester, find.text('Nova forma de pagamento'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome *'), nomeForma);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await bombearAteSumir(tester, find.text('Nova forma de pagamento'));

    final listaForma = await ApiService.dio.get('/formas-pagamento');
    final forma = (listaForma.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .firstWhere((f) => f['nome'] == nomeForma);
    final formaId = forma['id'] as int;
    semear.registrarForma(formaId);

    // 9. Desativa a forma pelo Switch da linha.
    final tileForma = find.widgetWithText(ListTile, nomeForma);
    await centralizarLinha(tester, tileForma);
    await tester
        .tap(find.descendant(of: tileForma, matching: find.byType(Switch)));
    await tester.pump(const Duration(milliseconds: 600));

    // Valida no backend: forma inativa.
    final formaApi = (await ApiService.dio.get('/formas-pagamento')).data as List;
    final formaAtual = formaApi
        .map((e) => Map<String, dynamic>.from(e as Map))
        .firstWhere((f) => f['id'] == formaId);
    expect(formaAtual['ativo'], false);
  });
}
