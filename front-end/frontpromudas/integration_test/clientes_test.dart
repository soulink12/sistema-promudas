// e2e de UI — Parte 3: cadastro, busca e edição de Clientes.
// Login → PDV → drawer "Consulta" → "Clientes" → FAB "Novo cliente" (dialog)
// → busca pelo nome → detalhes → editar telefone → salvar (com confirmação).
// Ver _support.dart para a infra compartilhada.
//
// Rodar: flutter test integration_test/clientes_test.dart -d windows
// Pré-requisito: backend de pé na 6072 + banco de teste.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontpromudas/core/services/api_service.dart';
import '_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cadastra, busca e edita um cliente', (tester) async {
    final nome = '__e2e_ui_cli_${DateTime.now().microsecondsSinceEpoch}';
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

    // 3. Drawer → Consulta → card "Clientes".
    await abrirItemDrawer(tester, 'Consulta');
    await bombearAte(tester, find.text('Clientes'));
    await tester.tap(find.text('Clientes'));
    await bombearAte(tester, find.byTooltip('Novo cliente'));

    // 4. FAB → dialog de cadastro. Preenche nome + telefone e salva.
    await tester.tap(find.byTooltip('Novo cliente'));
    await bombearAte(tester, find.text('Novo Cliente'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome *'), nome);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefone'), '11111111');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await bombearAteSumir(tester, find.text('Novo Cliente'));

    // 5. Descobre o id do cliente recém-criado (via API) para limpar no fim.
    final busca = await ApiService.dio
        .get('/clientes', queryParameters: {'busca': nome});
    final criado = (busca.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .firstWhere((c) => c['nome'] == nome);
    final clienteId = criado['id'] as int;
    semear.registrarCliente(clienteId);

    // 6. Busca pelo nome na listagem e abre os detalhes.
    final campoBuscaClientes = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Buscar por nome, CPF ou telefone...',
    );
    await tester.enterText(campoBuscaClientes, nome);
    final tile = find.widgetWithText(ListTile, nome);
    await bombearAte(tester, tile);
    await tester.tap(tile);

    // 7. Detalhes → lápis de editar → form de edição.
    final btnEditar = find.byTooltip('Editar cliente');
    await bombearAte(tester, btnEditar);
    await tester.tap(btnEditar);
    await bombearAte(tester, find.text('Editar Cliente'));

    // 8. Altera o telefone e salva (passa pela confirmação).
    final campoTelefone = find.widgetWithText(TextFormField, 'Telefone');
    await tester.ensureVisible(campoTelefone);
    await tester.enterText(campoTelefone, '99999999');
    // O botão fica no topo do form rolável; reexibe antes de tocar.
    final btnSalvar = find.widgetWithText(FilledButton, 'Salvar');
    await tester.ensureVisible(btnSalvar);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(btnSalvar);
    await bombearAte(tester, find.text('Confirmar edição'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));

    // Snackbar de sucesso confirma a gravação na UI.
    await bombearAte(tester, find.text('Cliente atualizado com sucesso!'));

    // 9. Valida no backend que o telefone foi atualizado.
    final ped = await ApiService.dio.get('/clientes/$clienteId');
    expect(ped.data['telefone_1'], '99999999');
  });
}
