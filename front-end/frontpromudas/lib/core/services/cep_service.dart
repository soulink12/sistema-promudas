import 'package:dio/dio.dart';

/// Endereço devolvido pela consulta de CEP.
class EnderecoCep {
  final String logradouro;
  final String bairro;
  final String cidade;
  final String estado;

  const EnderecoCep({
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.estado,
  });
}

/// Consulta o CEP no ViaCEP (serviço público, sem chave) para preencher o
/// endereço do cliente automaticamente.
///
/// Usa um Dio próprio: o [ApiService] aponta para o backend do Promudas, e
/// esta é uma chamada externa. Timeout curto de propósito — é uma comodidade,
/// não pode travar o cadastro se o serviço estiver fora do ar.
class CepService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  /// Devolve o endereço do [cep] ou `null` quando o CEP não existe, não tem 8
  /// dígitos, ou a consulta falha. Nunca lança — quem chama só preenche o que
  /// vier e deixa o usuário digitar o resto.
  static Future<EnderecoCep?> buscar(String cep) async {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8) return null;

    try {
      final resposta = await _dio.get('https://viacep.com.br/ws/$digitos/json/');
      final dados = resposta.data;
      if (dados is! Map) return null;
      // O ViaCEP responde 200 com {"erro": true} para CEP inexistente.
      if (dados['erro'] == true || dados['erro'] == 'true') return null;

      return EnderecoCep(
        logradouro: (dados['logradouro'] as String? ?? '').trim(),
        bairro: (dados['bairro'] as String? ?? '').trim(),
        cidade: (dados['localidade'] as String? ?? '').trim(),
        estado: (dados['uf'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
