import 'api_service.dart';

/// Busca as contas ativas cadastradas no backend.
/// Conta = para onde o valor do pagamento entra (ex: Fernando Antônio, Lucas).
class ContaService {
  Future<List<String>> listar() async {
    final response = await ApiService.dio.get('/contas');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados.map<String>((item) => item['nome'] as String).toList();
  }
}
