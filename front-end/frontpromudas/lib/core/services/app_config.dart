import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Configuração externa do app. No desktop, lida de um arquivo de texto simples
/// (`config.txt`, ver [_pastaDados]) — permite apontar o app para o backend
/// correto sem recompilar. No Android não há um arquivo editável pelo usuário
/// fora do app, então o servidor é configurado por uma tela (gear icon na
/// [TelaLogin], visível só no Android) e persistido via `SharedPreferences`
/// (ver [salvarUrlAndroid]).
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

  /// Chave usada no Android (`SharedPreferences`) para o endereço do servidor.
  static const String _chaveAndroid = 'api_base_url';

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
  ///
  /// No Android, o arquivo não se aplica — carrega de [_chaveAndroid] em vez
  /// disso (ver [_carregarAndroid]).
  static Future<void> carregar() async {
    if (Platform.isAndroid) {
      await _carregarAndroid();
      return;
    }
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
        // Um typo (ex.: faltar o "http://") gerava erro de rede confuso em
        // todas as telas; sem scheme válido, mantém o padrão.
        if (!_urlValida(l)) {
          // ignore: avoid_print
          print('AppConfig: URL inválida em config.txt ("$l"); usando padrão ($apiBaseUrl).');
          break;
        }
        apiBaseUrl = l;
        break;
      }
    } catch (e) {
      // Mantém o padrão (localhost) em qualquer falha de leitura.
      // ignore: avoid_print
      print('AppConfig: usando padrão ($apiBaseUrl). Falha ao ler config: $e');
    }
  }

  /// Carrega [apiBaseUrl] salva anteriormente por [salvarUrlAndroid]. Sem
  /// nada salvo (primeira execução), mantém o padrão — a tela de login pede
  /// a configuração antes do primeiro login funcionar de verdade.
  static Future<void> _carregarAndroid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salva = prefs.getString(_chaveAndroid);
      if (salva != null && _urlValida(salva)) {
        apiBaseUrl = salva;
      }
    } catch (_) {
      // Mantém o padrão em qualquer falha de leitura.
    }
  }

  /// Salva a URL do servidor configurada na tela de login (Android). Retorna
  /// `false` sem alterar nada se a URL não tiver um esquema/host válido.
  static Future<bool> salvarUrlAndroid(String url) async {
    final limpa = url.trim();
    if (!_urlValida(limpa)) return false;
    apiBaseUrl = limpa;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveAndroid, limpa);
    return true;
  }

  static bool _urlValida(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
