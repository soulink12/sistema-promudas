import 'api_service.dart';

/// Busca os clientes ativos cadastrados no backend.
class ClienteService {
  /// Lista clientes ativos. Com [busca], pesquisa no backend por nome, CPF/CNPJ
  /// ou telefone (todos os clientes); sem busca, o backend retorna só os últimos.
  Future<List<Map<String, dynamic>>> listar({String? busca}) async {
    final termo = busca?.trim() ?? '';
    final response = await ApiService.dio.get(
      '/clientes',
      queryParameters: termo.isNotEmpty ? {'busca': termo} : null,
    );
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados.map<Map<String, dynamic>>((item) => {
          'id': item['id'] as int,
          'nome': item['nome'] as String,
          'cpf': item['cpf_cnpj'] as String? ?? 'Não informado',
          'telefone': item['telefone_1'] as String? ?? 'Não informado',
        }).toList();
  }
}
