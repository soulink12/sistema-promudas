import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../vendas/screens/widgets/modal_busca_cliente.dart';

class TelaPedidos extends StatefulWidget {
  const TelaPedidos({super.key});

  @override
  State<TelaPedidos> createState() => _TelaPedidosState();
}

class _TelaPedidosState extends State<TelaPedidos> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _carregando = true;
  String? _erro;

  Map<String, dynamic>? _clienteFiltro;
  Map<String, dynamic>? _pedidoSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
  }

  Future<void> _carregarPedidos([String? clienteNome]) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final response = await ApiService.dio.get(
        '/pedidos',
        queryParameters:
            clienteNome != null && clienteNome.isNotEmpty ? {'cliente': clienteNome} : null,
      );
      final dados = response.data as List;
      setState(() {
        _pedidos = dados
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar os pedidos.';
        _carregando = false;
      });
    }
  }

  void _selecionarClienteFiltro(Map<String, dynamic> cliente) {
    setState(() {
      _clienteFiltro = cliente;
      _pedidoSelecionado = null;
    });
    _carregarPedidos(cliente['nome'] as String?);
  }

  void _limparFiltro() {
    setState(() {
      _clienteFiltro = null;
      _pedidoSelecionado = null;
    });
    _carregarPedidos();
  }

  void _selecionarPedido(Map<String, dynamic> pedido) {
    setState(() => _pedidoSelecionado = pedido);
  }

  void _abrirBuscaCliente() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: BuscaClienteModal(
                onClienteSelecionado: _selecionarClienteFiltro,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeCliente = _clienteFiltro?['nome'] as String?;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: InkWell(
          onTap: _abrirBuscaCliente,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nomeCliente ?? 'Todos os pedidos',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      nomeCliente != null
                          ? 'Filtrado por cliente'
                          : 'Últimos 20 pedidos',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        actions: [
          if (_clienteFiltro != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remover filtro',
              onPressed: _limparFiltro,
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? _buildErro()
              : _pedidoSelecionado != null
                  ? _buildDetalhes(_pedidoSelecionado!)
                  : _buildLista(),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(_erro!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _carregarPedidos,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_pedidos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum pedido encontrado.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: _pedidos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = _pedidos[index];
        final nomeCliente = p['clientes']?['nome'] as String? ?? 'Cliente desconhecido';
        final total = _toDouble(p['valor_total']);
        final data = _formatarDataHora(p['criado_em']);
        final statusPag = p['status_pagamento'] as String? ?? 'Pendente';

        return ListTile(
          leading: _badgeId(p['id'] as int),
          title: Text(nomeCliente, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${data ?? '—'}  •  R\$ ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: _chipStatus(statusPag),
          onTap: () => _selecionarPedido(p),
        );
      },
    );
  }

  Widget _buildDetalhes(Map<String, dynamic> pedido) {
    final nomeCliente = pedido['clientes']?['nome'] as String? ?? '—';
    final total = _toDouble(pedido['valor_total']);
    final ajuste = _toDouble(pedido['ajuste']);
    final data = _formatarDataHora(pedido['criado_em']);
    final statusPag = pedido['status_pagamento'] as String? ?? 'Pendente';
    final statusRet = pedido['status_retirada'] as String? ?? 'Pendente';
    final obs = pedido['observacoes'] as String?;

    final itens = (pedido['itens_pedido'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final pagamentos = (pedido['pagamentos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com botão voltar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar para a lista',
                onPressed: () => setState(() => _pedidoSelecionado = null),
              ),
              const SizedBox(width: 4),
              Text(
                'Pedido #${pedido['id']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Card de informações gerais
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nomeCliente,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(data ?? '—',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${total.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          if (ajuste != 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${ajuste < 0 ? 'Desconto' : 'Acréscimo'}: R\$ ${ajuste.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: ajuste < 0 ? Colors.blue[700] : Colors.orange[800]),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chipStatus(statusPag),
                      _chipStatus(statusRet, prefixo: 'Retirada: '),
                    ],
                  ),
                  if (obs != null && obs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Observações:',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(obs),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Itens do pedido
          _tituloSecao('Itens do Pedido'),
          Card(
            child: itens.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum item registrado.'),
                  )
                : Column(
                    children: [
                      // Cabeçalho da tabela
                      _linhaTabela(
                        context,
                        isHeader: true,
                        cells: const ['Produto', 'Qtd.', 'Preço Unit.', 'Total'],
                        flex: const [4, 1, 2, 2],
                      ),
                      const Divider(height: 1),
                      ...itens.map((item) {
                        final nomeProduto =
                            item['produtos']?['nome'] as String? ?? '—';
                        final qtd = item['quantidade'] as int? ?? 0;
                        final preco = _toDouble(item['valor_unitario']);
                        final totalItem = preco * qtd;
                        return Column(
                          children: [
                            _linhaTabela(
                              context,
                              cells: [
                                nomeProduto,
                                '$qtd',
                                'R\$ ${preco.toStringAsFixed(2)}',
                                'R\$ ${totalItem.toStringAsFixed(2)}',
                              ],
                              flex: const [4, 1, 2, 2],
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Pagamentos
          _tituloSecao('Pagamentos'),
          Card(
            child: pagamentos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum pagamento registrado.'),
                  )
                : Column(
                    children: pagamentos.map((pag) {
                      final dataPag = _formatarDataHora(pag['criado_em']) ?? '—';
                      final forma = pag['forma_pagamento'] as String? ?? '—';
                      final valor = _toDouble(pag['valor_pago']);
                      return ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(forma),
                        subtitle: Text(dataPag),
                        trailing: Text(
                          'R\$ ${valor.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.green[700],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _linhaTabela(
    BuildContext context, {
    required List<String> cells,
    required List<int> flex,
    bool isHeader = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: isHeader ? cs.surfaceContainerHighest : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(cells.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Text(
              cells[i],
              textAlign: i > 0 ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 13 : 14,
                color: isHeader ? cs.onSurfaceVariant : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _badgeId(int id) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Center(
        child: Text(
          '#$id',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800]),
        ),
      ),
    );
  }

  Widget _chipStatus(String status, {String prefixo = ''}) {
    Color cor;
    switch (status.toLowerCase()) {
      case 'pago':
      case 'realizada':
        cor = Colors.green;
        break;
      case 'parcial':
        cor = Colors.orange;
        break;
      default:
        cor = Colors.grey;
    }
    return Chip(
      label: Text(
        '$prefixo$status',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: cor.withAlpha(30),
      side: BorderSide(color: cor.withAlpha(80)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

  String? _formatarData(dynamic valor) {
    if (valor == null) return null;
    try {
      final dt = DateTime.parse(valor.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return valor.toString();
    }
  }

  String? _formatarDataHora(dynamic valor) {
    if (valor == null) return null;
    try {
      final dt = DateTime.parse(valor.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return valor.toString();
    }
  }
}
