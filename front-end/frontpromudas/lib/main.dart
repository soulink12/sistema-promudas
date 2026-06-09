import 'package:flutter/material.dart';
import 'core/services/theme_service.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
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
