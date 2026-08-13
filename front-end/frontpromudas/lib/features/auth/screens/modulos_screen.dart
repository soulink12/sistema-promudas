import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/botao_fechar_app.dart';
import '../../vendas/screens/venda_screen.dart';
import '../../entregas/screens/entrega_screen.dart';
import '../../admin/screens/admin_screen.dart';
import 'login_screen.dart';

class TelaModulos extends StatelessWidget {
  const TelaModulos({super.key});

  @override
  Widget build(BuildContext context) {
    final nomeUsuario = AuthService.usuario?['nome'] as String? ?? 'Usuário';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/promudas_logo.png',
                            height: 132,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bem-vindo, $nomeUsuario',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 48),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _CardModulo(
                                    icon: Icons.point_of_sale,
                                    titulo: 'PDV',
                                    descricao: 'Registrar vendas e pedidos',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaVenda(),
                                      ),
                                    ),
                                  ),
                                  _CardModulo(
                                    icon: Icons.inventory_2_outlined,
                                    titulo: 'Entregas',
                                    descricao: 'Registrar entregas de produtos',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaEntregas(),
                                      ),
                                    ),
                                  ),
                                  _CardModulo(
                                    icon: Icons.admin_panel_settings_outlined,
                                    titulo: 'Administração',
                                    descricao: 'Relatórios e cadastros',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaAdmin(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          TextButton.icon(
                            onPressed: () {
                              AuthService.logout();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TelaLogin(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Sair'),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const BotaoFecharApp(),
        ],
      ),
    );
  }
}

class _CardModulo extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _CardModulo({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 240,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 52, color: cs.primary),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    titulo,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descricao,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
