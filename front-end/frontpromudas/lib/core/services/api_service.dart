import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'app_config.dart';

/// Instância central do Dio para todas as chamadas à API.
/// A base URL vem de [AppConfig], carregado de `config.txt` no `main()` antes
/// do primeiro acesso ao Dio.
class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Criado de forma preguiçosa para garantir que [AppConfig.carregar] já rodou.
  static Dio? _dio;
  static Dio get dio => _dio ??= _criarDio();

  /// Descarta o cliente Dio atual — a baseUrl fica fixa no [BaseOptions] dele,
  /// então após mudar [AppConfig.apiBaseUrl] (tela de configuração de servidor
  /// no Android) é preciso recriar o cliente. A próxima chamada a [dio] já usa
  /// a URL nova.
  static void reconfigurar() {
    _dio = null;
  }

  /// Chamado quando a API responde 401 numa rota autenticada, ou seja, quando a
  /// sessão expirou (o token dura 8h). Definido no `main()`, que sabe navegar
  /// para o login — assim o `core` não precisa conhecer as telas.
  static void Function()? aoExpirarSessao;

  static Dio _criarDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (AuthService.token != null) {
          options.headers['Authorization'] = 'Bearer ${AuthService.token}';
        }
        handler.next(options);
      },
      onError: (erro, handler) {
        // Sessão expirada: sem isso, num PDV aberto o dia inteiro toda ação
        // passava a falhar com erro genérico e o operador ficava preso até
        // fechar e reabrir o app. O 401 do próprio login é senha errada, não
        // expiração — esse segue para a tela tratar.
        final ehRotaDeAuth = erro.requestOptions.path.contains('/auth/');
        if (erro.response?.statusCode == 401 &&
            !ehRotaDeAuth &&
            AuthService.token != null) {
          AuthService.logout();
          aoExpirarSessao?.call();
        }
        handler.next(erro);
      },
    ));
    return d;
  }
}
