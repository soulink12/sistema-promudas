import 'dart:io';

/// Configuração externa do app, lida de um arquivo de texto simples ao lado do
/// executável. Permite apontar o app para o backend correto (local ou servidor)
/// sem recompilar — basta editar o `config.txt` na pasta do `.exe`.
class AppConfig {
  /// Endereço base da API. Padrão aponta para o backend local de desenvolvimento.
  /// É sobrescrito por `carregar()` quando há um `config.txt` válido.
  static String apiBaseUrl = 'http://localhost:6072/api';

  /// Nome do arquivo de configuração, procurado na pasta do executável.
  static const String _nomeArquivo = 'config.txt';

  /// Conteúdo de exemplo criado na primeira execução, quando o arquivo não existe.
  static const String _modeloPadrao =
      '# Endereço do backend (uma linha). Exemplo:\n'
      '# http://192.168.0.50:6072/api\n'
      'http://localhost:6072/api\n';

  /// Lê o `config.txt` ao lado do executável e atualiza [apiBaseUrl].
  ///
  /// - Linhas em branco e iniciadas por `#` são ignoradas.
  /// - A primeira linha "útil" é usada como base URL.
  /// - Se o arquivo não existir, tenta criar um modelo comentado (best-effort).
  /// - Qualquer erro mantém o padrão e não interrompe o app.
  static Future<void> carregar() async {
    try {
      final pastaExecutavel = File(Platform.resolvedExecutable).parent.path;
      final arquivo = File('$pastaExecutavel${Platform.pathSeparator}$_nomeArquivo');

      if (!arquivo.existsSync()) {
        // Cria um modelo para o dono editar; falha silenciosa se a pasta for
        // somente-leitura.
        try {
          arquivo.writeAsStringSync(_modeloPadrao);
        } catch (_) {}
        return; // mantém o padrão na primeira execução
      }

      final linhas = arquivo.readAsLinesSync();
      for (final linha in linhas) {
        final l = linha.trim();
        if (l.isEmpty || l.startsWith('#')) continue;
        apiBaseUrl = l;
        break;
      }
    } catch (e) {
      // Mantém o padrão (localhost) em qualquer falha de leitura.
      // ignore: avoid_print
      print('AppConfig: usando padrão ($apiBaseUrl). Falha ao ler config: $e');
    }
  }
}
