/// Serviço responsável pela lógica de negócio do carrinho de compras.
/// Centraliza as operações de adicionar e remover itens, mantendo quantidades e totais.
/// TODO: substituir por SQLite — persistir o carrinho na tabela 'itens_venda' ao finalizar
class CarrinhoService {
  // Lista interna de itens da venda em andamento
  final List<Map<String, dynamic>> _itens = [];

  // Ajuste fixo em R$ com sinal — usado quando não é percentual
  double _ajusteFixo = 0.0;
  // Percentual com sinal (negativo = desconto, positivo = acréscimo)
  double _percentual = 0.0;
  bool _ehPercentual = false;
  String? _descricaoAjuste;

  /// Retorna os itens atuais do carrinho (somente leitura).
  List<Map<String, dynamic>> get itens => List.unmodifiable(_itens);

  /// Valor do ajuste em R$. Para ajuste percentual, recalcula sobre o subtotal
  /// atual, de modo que mudanças nos itens se reflitam automaticamente.
  double get ajuste {
    if (_ehPercentual && _percentual != 0.0) {
      return subtotal * (_percentual / 100);
    }
    return _ajusteFixo;
  }

  String? get descricaoAjuste => _descricaoAjuste;
  bool get ehPercentualAjuste => _ehPercentual;
  double get percentualAjuste => _percentual;

  /// Soma dos totais dos itens, sem ajuste.
  double get subtotal =>
      _itens.fold(0, (s, i) => s + (i['total'] as double));

  /// Total final após aplicar desconto ou acréscimo.
  double get totalComAjuste => subtotal + ajuste;

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

  /// Aplica desconto ou acréscimo ao pedido.
  /// Quando [ehPercentual] = true, [valor] é o percentual com sinal e o ajuste
  /// em R$ é recalculado automaticamente sempre que os itens mudarem.
  void aplicarAjuste(double valor, String descricao,
      {bool ehPercentual = false}) {
    _ehPercentual = ehPercentual;
    _descricaoAjuste = descricao;
    if (ehPercentual) {
      _percentual = valor;
      _ajusteFixo = 0.0;
    } else {
      _ajusteFixo = valor;
      _percentual = 0.0;
    }
  }

  /// Remove o ajuste do pedido.
  void removerAjuste() {
    _ajusteFixo = 0.0;
    _percentual = 0.0;
    _ehPercentual = false;
    _descricaoAjuste = null;
  }

  /// Limpa todos os itens e o ajuste, retornando o carrinho ao estado inicial.
  void limpar() {
    _itens.clear();
    removerAjuste();
  }
}
