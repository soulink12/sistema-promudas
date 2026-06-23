import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../auth/screens/login_screen.dart';
import '../../../clientes/screens/clientes_screen.dart';
import '../../../pedidos/screens/pedidos_screen.dart';
import '../../../configuracoes/screens/configuracoes_screen.dart';

/// Drawer (menu sanduíche) do módulo PDV. Cabeçalho com o usuário logado e itens
/// de navegação apenas das funções do PDV: Clientes, Pedidos e Aparência — além
/// de Trocar Módulo e Sair.
/// Relatórios, cadastros e conciliação financeira ficam no módulo Administração.
class DrawerPdv extends StatelessWidget {
  const DrawerPdv({super.key});

  @override
  Widget build(BuildContext context) {
    final nomeUsuario =
        AuthService.usuario?['nome'] as String? ?? 'Usuário';
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: cs.primary),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront, color: cs.onPrimary, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Sistema Promudas',
                    style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nomeUsuario,
                    style: TextStyle(
                        color: cs.onPrimary.withValues(alpha: 0.7),
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Trocar Módulo'),
            onTap: () {
              Navigator.pop(context); // fecha drawer
              Navigator.pop(context); // volta para TelaModulos
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('PDV'),
            selected: true,
            selectedColor: cs.primary,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Clientes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaListaClientes()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Pedidos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaPedidos()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configurações do app'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaConfiguracoes()),
              );
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: CoresSemanticas.erro),
            title: const Text('Sair', style: TextStyle(color: CoresSemanticas.erro)),
            onTap: () {
              AuthService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const TelaLogin()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
