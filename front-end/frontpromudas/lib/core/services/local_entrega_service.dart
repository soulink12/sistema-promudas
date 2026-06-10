import 'api_service.dart';

/// Busca os locais de entrega ativos cadastrados no backend.
class LocalEntregaService {
  Future<List<String>> listar() async {
    final response = await ApiService.dio.get('/locais-entrega');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados.map<String>((item) => item['nome'] as String).toList();
  }
}
