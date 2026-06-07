/// Serviço responsável pela lógica de negócio do carrinho de compras.
/// Centraliza as operações de adicionar e remover itens, mantendo quantidades e totais.
/// TODO: substituir por SQLite — persistir o carrinho na tabela 'itens_venda' ao finalizar
class CarrinhoService {
  // Lista interna de itens da venda em andamento
  final List<Map<String, dynamic>> _itens = [];

  // Ajuste do pedido em R$ (negativo = desconto, positivo = acréscimo)
  double _ajuste = 0.0;
  String? _descricaoAjuste;

  /// Retorna os itens atuais do carrinho (somente leitura).
  List<Map<String, dynamic>> get itens => List.unmodifiable(_itens);

  double get ajuste => _ajuste;
  String? get descricaoAjuste => _descricaoAjuste;

  /// Soma dos totais dos itens, sem ajuste.
  double get subtotal =>
      _itens.fold(0, (s, i) => s + (i['total'] as double));

  /// Total final após aplicar desconto ou acréscimo.
  double get totalComAjuste => subtotal + _ajuste;

  /// Adiciona um produto ao carrinho com a [quantidade] informada (padrão: 1).
  /// Se o produto já existir (mesmo id), soma a quantidade e recalcula o total.
  /// Caso contrário, insere o item com a quantidade recebida.
  void adicionarItem(Map<String, dynamic> produto, {int quantidade = 1}) {
    final index = _itens.indexWhere((item) => item['id'] == produto['id']);

    if (index != -1) {
      // Só incrementa a quantidade; preço e precoOriginal não são alterados
      _itens[index]['quantidade'] += quantidade;
      _itens[index]['total'] =
          _itens[index]['quantidade'] * _itens[index]['preco'];
    } else {
      _itens.add({
        'id': produto['id'],
        'nome': produto['nome'],
        'preco': produto['preco'] as double,
        // Referência imutável do preço cadastrado no sistema
        'precoOriginal': produto['preco'] as double,
        'quantidade': quantidade,
        'total': produto['preco'] * quantidade,
      });
    }
  }

  /// Altera a quantidade de um item e recalcula o total.
  void alterarQuantidade(dynamic id, int novaQtd) {
    final index = _itens.indexWhere((item) => item['id'] == id);
    if (index == -1 || novaQtd <= 0) return;
    _itens[index]['quantidade'] = novaQtd;
    _itens[index]['total'] = novaQtd * (_itens[index]['preco'] as double);
  }

  /// Altera o preço unitário de um item e recalcula o total.
  /// [precoOriginal] não é modificado, permitindo comparação visual na tela.
  void alterarPreco(dynamic id, double novoPreco) {
    final index = _itens.indexWhere((item) => item['id'] == id);
    if (index == -1 || novoPreco <= 0) return;
    _itens[index]['preco'] = novoPreco;
    _itens[index]['total'] = (_itens[index]['quantidade'] as int) * novoPreco;
  }

  /// Remove um item do carrinho pelo seu id.
  void removerItem(dynamic id) {
    _itens.removeWhere((item) => item['id'] == id);
  }

  /// Aplica um desconto (valor negativo) ou acréscimo (valor positivo) ao pedido.
  void aplicarAjuste(double valor, String descricao) {
    _ajuste = valor;
    _descricaoAjuste = descricao;
  }

  /// Remove o ajuste do pedido.
  void removerAjuste() {
    _ajuste = 0.0;
    _descricaoAjuste = null;
  }
}
