import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/theme_service.dart';
import 'features/auth/screens/login_screen.dart';

/// Chave do Navigator raiz — usada pelo atalho de teclado para voltar.
final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.carregar();
  runApp(const MeuViveiroApp());
}

class MeuViveiroApp extends StatelessWidget {
  const MeuViveiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Sistema Promudas',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          // Envolve toda a aplicação para tratar o Backspace como "voltar"
          builder: (context, child) => _AtalhoVoltarTeclado(
            child: child ?? const SizedBox.shrink(),
          ),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: mode,
          home: const TelaLogin(),
        );
      },
    );
  }
}

/// Faz com que a tecla Backspace funcione como o botão "voltar" em qualquer
/// tela, exceto quando o foco está num campo de texto (para não atrapalhar a
/// edição). Funciona também para fechar diálogos abertos.
class _AtalhoVoltarTeclado extends StatelessWidget {
  final Widget child;

  const _AtalhoVoltarTeclado({required this.child});

  /// Detecta se o foco atual pertence a um campo de texto (EditableText).
  bool _focoEmCampoDeTexto() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;

    var ehTexto = false;
    ctx.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        ehTexto = true;
        return false; // encontrou — interrompe a busca
      }
      return true;
    });
    return ehTexto;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            !_focoEmCampoDeTexto()) {
          final nav = _navigatorKey.currentState;
          if (nav != null && nav.canPop()) {
            nav.maybePop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
