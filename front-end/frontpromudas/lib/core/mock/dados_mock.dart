/// Classe que centraliza todos os dados fictícios (mock) do sistema.
/// Substitui temporariamente o banco de dados enquanto o SQLite não está integrado.
// TODO: substituir por SQLite — remover esta classe quando as consultas reais estiverem prontas
class DadosMock {
  // Lista simulada de clientes para quando o usuário quiser trocar e pesquisar
  // TODO: substituir por SQLite — buscar da tabela 'clientes' no banco
  final List<Map<String, dynamic>> clientesMock = [
    {
      'id': 1,
      'nome': 'Consumidor',
      'cpf': 'Não informado',
      'telefone': 'Não informado',
    },
    {
      'id': 3,
      'nome': 'João Silva',
      'cpf': '111.111.111-11',
      'telefone': '(11) 99999-1111',
    },
    {
      'id': 4,
      'nome': 'Maria Oliveira',
      'cpf': '222.222.222-22',
      'telefone': '(22) 98888-2222',
    },
  ];

}