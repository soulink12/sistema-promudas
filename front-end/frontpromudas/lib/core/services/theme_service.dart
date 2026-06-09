import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _chave = 'tema_escuro';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  // Deve ser chamado em main() antes de runApp
  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final escuro = prefs.getBool(_chave) ?? false;
    themeMode.value = escuro ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggleTheme() async {
    final novoModo =
        themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = novoModo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave, novoModo == ThemeMode.dark);
  }
}
