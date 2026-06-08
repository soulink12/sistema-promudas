import 'api_service.dart';

/// Busca os clientes ativos cadastrados no backend.
class ClienteService {
  Future<List<Map<String, dynamic>>> listar() async {
    final response = await ApiService.dio.get('/clientes');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados.map<Map<String, dynamic>>((item) => {
          'id': item['id'] as int,
          'nome': item['nome'] as String,
          'cpf': item['cpf_cnpj'] as String? ?? 'Não informado',
          'telefone': item['telefone_1'] as String? ?? 'Não informado',
        }).toList();
  }
}
