import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../auth/screens/login_screen.dart';
import '../../../configuracoes/screens/configuracoes_screen.dart';
import '../../../consulta/screens/consulta_hub_screen.dart';
import '../../../relatorios/screens/relatorios_hub_screen.dart';

/// Drawer (menu sanduíche) do módulo PDV. Cabeçalho com o usuário logado e o
/// sino de pagamentos sem conta; itens de navegação para troca de módulo,
/// Consulta, Relatórios, Configurações e logout.
class DrawerPdv extends StatelessWidget {
  /// Quantidade de pagamentos sem conta — alimenta o badge do sino.
  final int pendentesSemConta;

  /// Acionado ao tocar o sino (abre os pagamentos sem conta e, ao voltar,
  /// atualiza o badge — a tela dona cuida disso).
  final VoidCallback onAbrirPagamentosSemConta;

  const DrawerPdv({
    super.key,
    required this.pendentesSemConta,
    required this.onAbrirPagamentosSemConta,
  });

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
            child: Stack(
              children: [
                Align(
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
                // Sino de notificações (canto superior direito do header).
                // FUTURO: centro de notificações geral, agregando todos os tipos
                // de alerta. Hoje a única fonte é "pagamentos sem conta".
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Pagamentos sem conta',
                    icon: Badge(
                      isLabelVisible: pendentesSemConta > 0,
                      label: Text('$pendentesSemConta'),
                      child: Icon(
                        pendentesSemConta > 0
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: cs.onPrimary,
                      ),
                    ),
                    onPressed: onAbrirPagamentosSemConta,
                  ),
                ),
              ],
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
            leading: const Icon(Icons.search),
            title: const Text('Consulta'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TelaConsultaHub()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Relatórios'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TelaRelatoriosHub()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TelaConfiguracoes()),
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
