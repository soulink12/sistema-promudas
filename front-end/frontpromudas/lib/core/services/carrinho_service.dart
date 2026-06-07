/// Serviço responsável pela lógica de negócio do carrinho de compras.
/// Centraliza as operações de adicionar e remover itens, mantendo quantidades e totais.
/// TODO: substituir por SQLite — persistir o carrinho na tabela 'itens_venda' ao finalizar
class CarrinhoService {
  // Lista interna de itens da venda em andamento
  final List<Map<String, dynamic>> _itens = [];

  /// Retorna os itens atuais do carrinho (somente leitura).
  List<Map<String, dynamic>> get itens => List.unmodifiable(_itens);

  /// Adiciona um produto ao carrinho.
  /// Se o produto já existir (mesmo id), incrementa a quantidade e recalcula o total.
  /// Caso contrário, insere o item com quantidade 1.
  void adicionarItem(Map<String, dynamic> produto) {
    final index = _itens.indexWhere((item) => item['id'] == produto['id']);

    if (index != -1) {
      _itens[index]['quantidade']++;
      _itens[index]['total'] =
          _itens[index]['quantidade'] * _itens[index]['preco'];
    } else {
      _itens.add({
        'id': produto['id'],
        'nome': produto['nome'],
        'preco': produto['preco'],
        'quantidade': 1,
        'total': produto['preco'],
      });
    }
  }

  /// Remove um item do carrinho pelo seu id.
  void removerItem(dynamic id) {
    _itens.removeWhere((item) => item['id'] == id);
  }
}
