import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamanho da fonte de todo o software. Cada nível é 15% maior que o anterior.
enum TamanhoFonte { pequeno, medio, grande }

extension TamanhoFonteX on TamanhoFonte {
  /// Fator de escala aplicado ao texto. Pequeno = 100%, médio = +15%,
  /// grande = +15% sobre o médio (≈ 1.3225).
  double get escala {
    switch (this) {
      case TamanhoFonte.pequeno:
        return 1.0;
      case TamanhoFonte.medio:
        return 1.15;
      case TamanhoFonte.grande:
        return 1.15 * 1.15;
    }
  }

  String get label {
    switch (this) {
      case TamanhoFonte.pequeno:
        return 'Pequeno';
      case TamanhoFonte.medio:
        return 'Médio';
      case TamanhoFonte.grande:
        return 'Grande';
    }
  }
}

class ThemeService {
  static const _chave = 'tema_escuro';
  static const _chaveFonte = 'tamanho_fonte';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  // Tamanho da fonte global — padrão pequeno (comportamento atual)
  static final ValueNotifier<TamanhoFonte> tamanhoFonte =
      ValueNotifier(TamanhoFonte.pequeno);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  // Deve ser chamado em main() antes de runApp
  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final escuro = prefs.getBool(_chave) ?? false;
    themeMode.value = escuro ? ThemeMode.dark : ThemeMode.light;

    final idxFonte = prefs.getInt(_chaveFonte) ?? 0;
    tamanhoFonte.value = TamanhoFonte
        .values[idxFonte.clamp(0, TamanhoFonte.values.length - 1)];
  }

  static Future<void> toggleTheme() async {
    final novoModo =
        themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = novoModo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave, novoModo == ThemeMode.dark);
  }

  static Future<void> definirTamanhoFonte(TamanhoFonte tamanho) async {
    tamanhoFonte.value = tamanho;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chaveFonte, tamanho.index);
  }
}
