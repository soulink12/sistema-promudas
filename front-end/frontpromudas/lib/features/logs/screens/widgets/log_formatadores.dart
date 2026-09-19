// Rótulos em português para os valores crus de `entidade`/`acao` que vêm da
// API (ver logService.js no backend) e formatação do snapshot (JSON) como
// texto indentado "chave: valor".

import '../../../../core/utils/formatadores.dart';

const Map<String, String> _rotulosEntidade = {
  'pedido': 'Pedido',
  'orcamento': 'Orçamento',
  'cliente': 'Cliente',
  'produto': 'Produto',
  'pagamento': 'Pagamento',
  'entrega': 'Entrega',
  'cheque': 'Cheque',
  'forma_pagamento': 'Forma de pagamento',
  'temporada': 'Temporada',
};

// Entidades cujo nome em português é feminino, para concordância do particípio.
const Set<String> _entidadesFemininas = {'entrega', 'forma_pagamento', 'temporada'};

const Map<String, String> _participiosMasculinos = {
  'criacao': 'criado',
  'atualizacao': 'atualizado',
  'exclusao': 'excluído',
  'aprovacao': 'aprovado',
  'recusa': 'recusado',
  'atualizacao_automatica': 'atualizado automaticamente',
};

const Map<String, String> _participiosFemininos = {
  'criacao': 'criada',
  'atualizacao': 'atualizada',
  'exclusao': 'excluída',
  'aprovacao': 'aprovada',
  'recusa': 'recusada',
  'atualizacao_automatica': 'atualizada automaticamente',
};

String rotuloEntidade(String? entidade) =>
    _rotulosEntidade[entidade] ?? entidade ?? 'Registro';

/// Ex.: "Pedido criado", "Entrega atualizada", "Orçamento aprovado".
String rotuloEvento(String? entidade, String? acao) {
  final rotulo = rotuloEntidade(entidade);
  final feminino = _entidadesFemininas.contains(entidade);
  final mapa = feminino ? _participiosFemininos : _participiosMasculinos;
  final participio = mapa[acao] ?? acao ?? 'alterado';
  return '$rotulo $participio';
}

const Map<String, String> _rotulosAcao = {
  'criacao': 'Criação',
  'atualizacao': 'Atualização',
  'exclusao': 'Exclusão',
  'aprovacao': 'Aprovação',
  'recusa': 'Recusa',
  'atualizacao_automatica': 'Atualização automática',
};

String rotuloAcao(String? acao) => _rotulosAcao[acao] ?? acao ?? '—';

String _formatarValorSimples(dynamic v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Sim' : 'Não';
  return v.toString();
}

/// Formata um valor (tipicamente o `snapshot` de uma atividade) como texto
/// indentado de "chave: valor", percorrendo Maps/Lists aninhados.
String formatarSnapshot(dynamic valor, [int nivel = 0]) {
  final indentacao = '  ' * nivel;
  if (valor is Map) {
    if (valor.isEmpty) return '$indentacao(vazio)';
    return valor.entries.map((e) {
      final chave = e.key.toString();
      final v = e.value;
      if ((v is Map && v.isNotEmpty) || (v is List && v.isNotEmpty)) {
        return '$indentacao$chave:\n${formatarSnapshot(v, nivel + 1)}';
      }
      return '$indentacao$chave: ${_formatarValorSimples(v)}';
    }).join('\n');
  }
  if (valor is List) {
    if (valor.isEmpty) return '$indentacao(nenhum)';
    return valor.asMap().entries.map((e) {
      final v = e.value;
      if ((v is Map && v.isNotEmpty) || (v is List && v.isNotEmpty)) {
        return '$indentacao- item ${e.key + 1}:\n${formatarSnapshot(v, nivel + 1)}';
      }
      return '$indentacao- ${_formatarValorSimples(v)}';
    }).join('\n');
  }
  return '$indentacao${_formatarValorSimples(valor)}';
}

// Campos cujo valor é monetário — exibidos em R$ em vez de número cru.
const Set<String> _camposMonetarios = {
  'valor_total',
  'valor_unitario',
  'valor_pago',
  'ajuste',
  'valor',
  'valor_kg_escambo',
  'preco',
  'saldo_credito',
};

/// Formata um valor de diferença (lado "de" ou "para" de um campo alterado)
/// — escalares inline, Maps/Listas com o mesmo formato indentado do snapshot.
/// `campo` (nome cru, ex. "valor_total") decide se o número vira moeda.
String formatarValorDiferenca(dynamic valor, [String? campo]) {
  if (valor is Map || valor is List) return formatarSnapshot(valor);
  if (campo != null && _camposMonetarios.contains(campo)) {
    final numero = valor is num ? valor : num.tryParse(valor?.toString() ?? '');
    if (numero != null) return formatarMoeda(numero);
  }
  return _formatarValorSimples(valor);
}

const Map<String, String> _rotulosCampoEspeciais = {
  'itens_pedido': 'Itens do pedido',
  'itens_orcamento': 'Itens do orçamento',
  'itens_entrega': 'Itens da entrega',
  'itens_interesse': 'Mudas de interesse',
};

/// Humaniza o nome cru de um campo (snake_case) pra exibição, ex.
/// "valor_total" -> "Valor total". Sem dicionário exaustivo — é uma
/// aproximação legível, não uma tradução completa.
String rotuloCampo(String campo) {
  final especial = _rotulosCampoEspeciais[campo];
  if (especial != null) return especial;
  final semUnderscore = campo.replaceAll('_', ' ');
  if (semUnderscore.isEmpty) return semUnderscore;
  return semUnderscore[0].toUpperCase() + semUnderscore.substring(1);
}

/// Nome de exibição de um item de pedido/orçamento (produto), com fallback
/// pro id do produto se o nome não veio no snapshot.
String rotuloItem(Map<String, dynamic> item) {
  final nomeProduto = (item['produtos'] as Map?)?['nome'] as String?;
  if (nomeProduto != null) return nomeProduto;
  final produtoId = item['produto_id'];
  return produtoId != null ? 'Produto #$produtoId' : 'Item';
}

/// Resumo qtd/valor de um item, ex. "qtd. 3 × R\$ 4,00". Itens sem preço
/// unitário (ex. itens_entrega, que só tem produto+quantidade) mostram só a
/// quantidade.
String resumoItem(Map<String, dynamic> item) {
  final quantidade = item['quantidade'];
  if (quantidade == null) return '';
  final valorUnitario = item['valor_unitario'];
  if (valorUnitario == null) return 'qtd. $quantidade';
  final numero = valorUnitario is num ? valorUnitario : num.tryParse(valorUnitario.toString());
  final valorFormatado = numero != null ? formatarMoeda(numero) : _formatarValorSimples(valorUnitario);
  return 'qtd. $quantidade × $valorFormatado';
}
