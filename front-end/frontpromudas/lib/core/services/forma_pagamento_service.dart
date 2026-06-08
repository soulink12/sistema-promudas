import 'api_service.dart';

/// Busca as formas de pagamento ativas cadastradas no backend.
class FormaPagamentoService {
  Future<List<String>> listar() async {
    final response = await ApiService.dio.get('/formas-pagamento');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados.map((item) => item['nome'] as String).toList();
  }
}
