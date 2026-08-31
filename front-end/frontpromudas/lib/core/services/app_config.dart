import 'dart:io';

/// Configuração externa do app, lida de um arquivo de texto simples. Permite
/// apontar o app para o backend correto (local ou servidor) sem recompilar —
/// basta editar o `config.txt` (ver [_pastaDados] para onde ele mora).
class AppConfig {
  /// Endereço base da API. Padrão aponta para o backend local de desenvolvimento.
  /// É sobrescrito por `carregar()` quando há um `config.txt` válido.
  static String apiBaseUrl = 'http://localhost:6072/api';

  /// URL do manifesto de atualização (`app-archive.json`), servido pelo mesmo
  /// backend na rota pública `/updates`. Derivada de [apiBaseUrl] trocando o
  /// sufixo `/api` por `/updates/...`, para que o mesmo `config.txt` aponte a
  /// API e as atualizações para o mesmo servidor — sem segunda configuração.
  static Uri get updateArchiveUrl {
    var base = apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - '/api'.length);
    }
    return Uri.parse('$base/updates/app-archive.json');
  }

  /// Nome do arquivo de configuração.
  static const String _nomeArquivo = 'config.txt';

  /// Nome da subpasta usada dentro da pasta de dados do usuário (ver [_pastaDados]).
  static const String _pastaApp = 'SistemaPromudas';

  /// Conteúdo de exemplo criado na primeira execução, quando o arquivo não existe.
  static const String _modeloPadrao =
      '# Endereço do backend (uma linha). Exemplo:\n'
      '# http://192.168.0.50:6072/api\n'
      'http://localhost:6072/api\n';

  /// Pasta onde o `config.txt` mora: uma pasta de dados do usuário
  /// (`%APPDATA%\SistemaPromudas` no Windows, `~/.config/SistemaPromudas` no
  /// Linux/macOS), **fora** da pasta do executável.
  ///
  /// Importante: o auto-update (`desktop_updater`) troca a pasta inteira do
  /// executável a cada atualização — um `config.txt` salvo ali (como era
  /// antes) é apagado a cada atualização, forçando reconfiguração toda vez.
  /// Guardando numa pasta de dados do usuário, o arquivo sobrevive.
  static Directory _pastaDados() {
    final base = Platform.isWindows
        ? Platform.environment['APPDATA']
        : Platform.environment['HOME'];
    if (base == null || base.isEmpty) {
      // Variável de ambiente ausente (bem incomum): cai de volta para a
      // pasta do executável, mesmo sem sobreviver a atualizações.
      return File(Platform.resolvedExecutable).parent;
    }
    final subpasta = Platform.isWindows ? _pastaApp : '.config${Platform.pathSeparator}$_pastaApp';
    return Directory('$base${Platform.pathSeparator}$subpasta');
  }

  /// Lê o `config.txt` e atualiza [apiBaseUrl].
  ///
  /// - Linhas em branco e iniciadas por `#` são ignoradas.
  /// - A primeira linha "útil" é usada como base URL.
  /// - Se o arquivo não existir, migra o `config.txt` antigo (salvo ao lado
  ///   do executável em versões anteriores a esta correção) quando existir,
  ///   ou cria um modelo comentado — best-effort.
  /// - Qualquer erro mantém o padrão e não interrompe o app.
  static Future<void> carregar() async {
    try {
      final pastaDados = _pastaDados();
      final arquivo = File('${pastaDados.path}${Platform.pathSeparator}$_nomeArquivo');

      if (!arquivo.existsSync()) {
        try {
          pastaDados.createSync(recursive: true);
          final antigo = File(
            '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$_nomeArquivo',
          );
          if (antigo.existsSync()) {
            arquivo.writeAsStringSync(antigo.readAsStringSync());
          } else {
            arquivo.writeAsStringSync(_modeloPadrao);
          }
        } catch (_) {}
        if (!arquivo.existsSync()) return; // mantém o padrão
      }

      final linhas = arquivo.readAsLinesSync();
      for (final linha in linhas) {
        // Remove comentário inline (tudo a partir do '#') e espaços nas pontas.
        // Cobre tanto a linha "# comentário" quanto "url # comentário".
        final l = linha.split('#').first.trim();
        if (l.isEmpty) continue;
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
