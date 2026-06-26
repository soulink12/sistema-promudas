import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferência local da pasta onde os PDFs de pedido são salvos.
///
/// É uma configuração por máquina (cada usuário escolhe a sua), persistida em
/// `shared_preferences` — segue o mesmo padrão de [ThemeService]. Quando não
/// definida, o app pede que o usuário a configure em Configurações antes de
/// emitir o primeiro PDF.
class PdfConfigService {
  static const _chavePasta = 'pasta_pdfs';

  /// Caminho da pasta escolhida pelo usuário. `null` enquanto não configurada.
  static final ValueNotifier<String?> pasta = ValueNotifier(null);

  /// Lê a pasta salva. Deve ser chamado em `main()` antes de `runApp`.
  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final salva = prefs.getString(_chavePasta);
    pasta.value = (salva != null && salva.trim().isNotEmpty) ? salva : null;
  }

  /// Define (ou limpa) a pasta de destino dos PDFs.
  static Future<void> definirPasta(String? caminho) async {
    final valor = (caminho != null && caminho.trim().isNotEmpty) ? caminho.trim() : null;
    pasta.value = valor;
    final prefs = await SharedPreferences.getInstance();
    if (valor == null) {
      await prefs.remove(_chavePasta);
    } else {
      await prefs.setString(_chavePasta, valor);
    }
  }
}
