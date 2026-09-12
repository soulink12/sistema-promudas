import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';

/// Histórico de atividades (criação/alteração/exclusão) e log de erros reais
/// do sistema. Ver `src/routes/logRoutes.js` no backend.
class LogService {
  Future<Map<String, dynamic>> listarAtividades({
    String? entidade,
    int? entidadeId,
    int? usuarioId,
    String? acao,
    DateTime? de,
    DateTime? ate,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await ApiService.dio.get(
      '/logs',
      queryParameters: _filtros(
        entidade: entidade,
        entidadeId: entidadeId,
        usuarioId: usuarioId,
        acao: acao,
        de: de,
        ate: ate,
        page: page,
        pageSize: pageSize,
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buscarAtividade(int id) async {
    final response = await ApiService.dio.get('/logs/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> listarErros({
    DateTime? de,
    DateTime? ate,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await ApiService.dio.get(
      '/logs/erros',
      queryParameters: _filtros(de: de, ate: ate, page: page, pageSize: pageSize),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> buscarErro(int id) async {
    final response = await ApiService.dio.get('/logs/erros/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Baixa o CSV do histórico já filtrado (sem paginação — o backend limita
  /// internamente a exportação a um teto de segurança).
  Future<Uint8List> exportarAtividadesCSV({
    String? entidade,
    DateTime? de,
    DateTime? ate,
  }) async {
    final response = await ApiService.dio.get(
      '/logs/exportar',
      queryParameters: {'formato': 'csv', ..._filtros(entidade: entidade, de: de, ate: ate)},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data as List<int>);
  }

  Map<String, dynamic> _filtros({
    String? entidade,
    int? entidadeId,
    int? usuarioId,
    String? acao,
    DateTime? de,
    DateTime? ate,
    int? page,
    int? pageSize,
  }) {
    final params = <String, dynamic>{};
    if (entidade != null) params['entidade'] = entidade;
    if (entidadeId != null) params['entidadeId'] = entidadeId;
    if (usuarioId != null) params['usuarioId'] = usuarioId;
    if (acao != null) params['acao'] = acao;
    if (de != null) params['de'] = de.toIso8601String();
    if (ate != null) params['ate'] = ate.toIso8601String();
    if (page != null) params['page'] = page;
    if (pageSize != null) params['pageSize'] = pageSize;
    return params;
  }
}
