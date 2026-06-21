// e2e de UI — Parte 1: módulo Entregas.
// Login → módulo Entregas → registrar entrega parcial → completar entrega.
// Ver _support.dart para a infra compartilhada.
//
// Rodar: flutter test integration_test/entregas_test.dart -d windows
// Pré-requisito: backend de pé na 6072 + banco de teste.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontpromudas/core/services/api_service.dart';
import '_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registra entrega parcial e depois completa a entrega', (tester) async {
    final semear = Semear();
    addTearDown(() async => semear.limpar());

    // 1. App + login (tela de módulos).
    await iniciarApp(tester);
    await fazerLogin(tester);

    // 2. Semeia produto + pedido (Consumidor id=1) com 1 item qtd 5.
    final produtoId = await semear.produto(preco: 10);
    final pedidoId = await semear.pedido(
      clienteId: 1,
      itens: [{'produto_id': produtoId, 'quantidade': 5, 'valor_unitario': 10}],
    );

    // 3. Entra no módulo Entregas.
    await tester.tap(find.text('Entregas'));
    await bombearAte(tester, find.textContaining('#$pedidoId ·'));

    // 4. Entrega parcial (2 de 5) → status Parcial.
    await registrarEntrega(tester, pedidoId, 2);
    var status = await statusEntrega(pedidoId);
    expect(status, 'Parcial', reason: 'após entregar 2 de 5 deveria ser Parcial');

    // 5. Completa a entrega (mais 3) → status Entregue.
    await bombearAte(tester, find.textContaining('#$pedidoId ·'));
    await registrarEntrega(tester, pedidoId, 3);
    status = await statusEntrega(pedidoId);
    expect(status, 'Entregue', reason: 'após entregar o restante deveria ser Entregue');
  });
}

/// Abre o modal de entrega do pedido [pedidoId], lança [qtd] do item, escolhe o
/// local "Paraíso" e confirma. Espera o modal fechar (POST concluído).
Future<void> registrarEntrega(WidgetTester tester, int pedidoId, int qtd) async {
  final cardMeta = find.textContaining('#$pedidoId ·');
  await bombearAte(tester, cardMeta);

  final registrar = find.descendant(
    of: find.ancestor(of: cardMeta, matching: find.byType(Card)),
    matching: find.widgetWithText(FilledButton, 'Registrar'),
  );
  await tester.tap(registrar);
  await bombearAte(tester, find.text('Confirmar Entrega'));

  final campoQtd = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == 'Qtd',
  );
  await tester.enterText(campoQtd, '$qtd');
  await tester.pump(const Duration(milliseconds: 200));

  await selecionarDropdown(
    tester,
    find.byType(DropdownButtonFormField<String>),
    'Paraíso',
  );

  await tester.tap(find.widgetWithText(FilledButton, 'Confirmar Entrega'));
  // Modal fecha após o POST concluir (onSalvo faz Navigator.pop).
  await bombearAteSumir(tester, find.byType(AlertDialog));
}

/// Lê o status_entrega atual do pedido via API.
Future<String?> statusEntrega(int pedidoId) async {
  final r = await ApiService.dio.get('/pedidos/$pedidoId');
  return r.data['status_entrega'] as String?;
}
