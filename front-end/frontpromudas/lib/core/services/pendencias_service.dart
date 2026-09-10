import 'api_service.dart';

/// Contagem das pendências que alimentam os badges (sino do drawer, card de
/// Administração, tela de Notificações).
///
/// Existia uma cópia dessa lógica em cada uma dessas três telas, e elas já
/// tinham divergido: o sino de Entregas contava só os pagamentos sem conta,
/// enquanto Administração e Notificações somavam também os cheques a
/// depositar — o mesmo ícone mostrava números diferentes.
class Pendencias {
  final int? pagamentosSemConta;
  final int? chequesADepositar;

  const Pendencias({this.pagamentosSemConta, this.chequesADepositar});

  /// `null` em algum tipo significa que a consulta falhou — diferente de zero,
  /// que significa "não há pendência". A tela decide como mostrar ("—" vs "0").
  bool get algumaFalhou => pagamentosSemConta == null || chequesADepositar == null;

  int get total => (pagamentosSemConta ?? 0) + (chequesADepositar ?? 0);
}

class PendenciasService {
  static Future<int?> _contar(String caminho) async {
    try {
      final resposta = await ApiService.dio.get(caminho);
      return (resposta.data as List).length;
    } catch (_) {
      return null;
    }
  }

  static Future<Pendencias> contar() async {
    final resultados = await Future.wait([
      _contar('/pagamentos/pendentes-conta'),
      _contar('/cheques/a-depositar'),
    ]);

    return Pendencias(
      pagamentosSemConta: resultados[0],
      chequesADepositar: resultados[1],
    );
  }
}
