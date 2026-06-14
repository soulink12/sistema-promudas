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
    ));
    return d;
  }
}
