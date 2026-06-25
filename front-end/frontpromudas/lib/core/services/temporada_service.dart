import 'api_service.dart';

/// Temporadas (safras) do sistema. A temporada ativa define a numeração dos
/// novos pedidos (ex.: 26-1, 26-2). É salva no backend e compartilhada por
/// todos os usuários. Gerenciada no módulo de Administração.
class TemporadaService {
  /// Lista todas as temporadas (mais recente primeiro): `{id, ano, ativo}`.
  Future<List<Map<String, dynamic>>> listar() async {
    final response = await ApiService.dio.get('/temporadas');
    final List<dynamic> dados = response.data as List<dynamic>;
    return dados.cast<Map<String, dynamic>>();
  }

  /// Cria uma temporada para um ano.
  Future<void> criar(int ano) async {
    await ApiService.dio.post('/temporadas', data: {'ano': ano});
  }

  /// Define qual temporada fica ativa (desativa as demais no backend).
  Future<void> ativar(int id) async {
    await ApiService.dio.put('/temporadas/$id/ativar');
  }
}
