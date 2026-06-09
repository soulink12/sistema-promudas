import 'api_service.dart';

/// Busca os produtos ativos cadastrados no backend.
class ProdutoService {
  Future<List<Map<String, dynamic>>> listar() async {
    final response = await ApiService.dio.get('/produtos');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados
        .where((item) => (item['ativo'] as bool? ?? true))
        .map<Map<String, dynamic>>((item) => {
              'id': item['id'] as int,
              'nome': item['nome'] as String,
              'preco': double.parse(item['preco'].toString()),
            })
        .toList();
  }
}
