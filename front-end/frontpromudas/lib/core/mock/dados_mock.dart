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

  // Lista simulada de produtos disponíveis para venda
  // TODO: substituir por SQLite — buscar da tabela 'produtos' no banco
  final List<Map<String, dynamic>> produtosMock = [
    {'id': 1, 'nome': 'Muda de Açaí BRS', 'preco': 2.50},
    {'id': 2, 'nome': 'Muda de Cacau Clone', 'preco': 4.00},
    {'id': 3, 'nome': 'Muda de Cupuaçu', 'preco': 3.50},
    {'id': 4, 'nome': 'Semente de Andiroba', 'preco': 1.20},
    {'id': 5, 'nome': 'Muda de Banana Prata', 'preco': 5.00},
    {'id': 6, 'nome': 'Adubo Orgânico 1kg', 'preco': 15.00},
  ];
}