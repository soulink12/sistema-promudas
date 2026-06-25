import 'api_service.dart';

/// Busca as formas de pagamento ativas cadastradas no backend.
class FormaPagamentoService {
  Future<List<Map<String, dynamic>>> listar() async {
    final response = await ApiService.dio.get('/formas-pagamento');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados
        .where((item) => (item['ativo'] as bool? ?? true))
        .map((item) => <String, dynamic>{
              'id': item['id'] as int,
              'nome': item['nome'] as String,
              'pagamentoPosterior': item['pagamento_posterior'] as bool? ?? false,
              'contaPosterior': item['conta_posterior'] as bool? ?? false,
              'depositoPosterior': item['deposito_posterior'] as bool? ?? false,
              'parceladoEmAte': item['parcelado_em_ate'] as int? ?? 1,
              'escambo': item['escambo'] as bool? ?? false,
              // Decimal vem como String no JSON — parse robusto.
              'valorKgEscambo': item['valor_kg_escambo'] == null
                  ? null
                  : double.tryParse(item['valor_kg_escambo'].toString()),
            })
        .toList();
  }
}
