import 'api_service.dart';

/// Acesso aos cheques registrados nos pagamentos.
/// Cheque = pagamento em cheque que precisa ser depositado; enquanto não tem
/// data de depósito, aparece em "cheques a depositar".
class ChequeService {
  /// Cheques ainda não depositados (de pedidos ativos).
  Future<List<Map<String, dynamic>>> listarADepositar() async {
    final response = await ApiService.dio.get('/cheques/a-depositar');
    return (response.data as List)
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Registra o depósito de um cheque (define a data + marca como depositado) e,
  /// opcionalmente, completa/corrige os dados do cheque.
  Future<void> registrarDeposito(int id, Map<String, dynamic> dados) async {
    await ApiService.dio.put('/cheques/$id', data: dados);
  }
}
