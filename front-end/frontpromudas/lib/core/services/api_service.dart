import 'package:dio/dio.dart';
import 'auth_service.dart';

/// Instância central do Dio para todas as chamadas à API.
/// Base URL aponta para o servidor local na porta configurada no backend.
class ApiService {
  static const String baseUrl = 'http://localhost:6072/api';

  static final Dio dio = _criarDio();

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
