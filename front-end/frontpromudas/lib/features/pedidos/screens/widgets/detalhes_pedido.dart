import 'package:flutter/material.dart';
import 'lista_pedidos.dart' show ChipStatus;

class DetalhesPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final bool salvando;
  final VoidCallback onVoltar;
  final VoidCallback onRegistrarPagamento;
  final VoidCallback onEmitirPdf;
  final VoidCallback onEditar;
  final VoidCallback onTapCliente;
  final void Function(Map<String, dynamic> pagamento) onEditarPagamento;
  final void Function(Map<String, dynamic> pagamento) onExcluirPagamento;

  const DetalhesPedido({
    super.key,
    required this.pedido,
    required this.salvando,
    required this.onVoltar,
    required this.onRegistrarPagamento,
    required this.onEmitirPdf,
    required this.onEditar,
    required this.onTapCliente,
    required this.onEditarPagamento,
    required this.onExcluirPagamento,
  });

  @override
  Widget build(BuildContext context) {
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
    final todosPagamentos = (pedido['pagamentos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final retiradas = (pedido['retiradas'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Os itens da retirada não trazem o nome do produto — montamos o mapa
    // a partir dos itens do pedido (que já vêm com produtos.nome).
    final nomesPorProduto = <int, String>{};
    for (final item in itens) {
      final id = item['produto_id'] as int?;
      final nome = item['produtos']?['nome'] as String?;
      if (id != null && nome != null) nomesPorProduto[id] = nome;
    }

    final pagamentosReais =
        todosPagamentos.where((p) => p['pagamento_posterior'] != true).toList();
    final totalPagoReal = pagamentosReais
        .fold<double>(0.0, (s, p) => s + _toDouble(p['valor_pago']));
    final saldoCredito = (total - totalPagoReal).clamp(0.0, double.infinity);

    final podePagar = statusPag == 'Pendente' || statusPag == 'Parcial';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar para a lista',
                onPressed: onVoltar,
              ),
              const SizedBox(width: 4),
              Text(
                'Pedido #${pedido['id']}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar pedido',
                onPressed: onEditar,
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
                            // Nome do cliente clicável → abre os detalhes do cliente
                            InkWell(
                              onTap: onTapCliente,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        nomeCliente,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(data ?? '—',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
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
                                  color: ajuste < 0
                                      ? Colors.blue[700]
                                      : Colors.orange[800]),
                            ),
                          ],
                          if (saldoCredito > 0.005) ...[
                            const SizedBox(height: 4),
                            Text(
                              'A receber: R\$ ${saldoCredito.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800]),
                            ),
                          ],
                          if (totalPagoReal > total + 0.01) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14, color: Colors.amber[800]),
                                const SizedBox(width: 4),
                                Text(
                                  'Crédito de R\$ ${(totalPagoReal - total).toStringAsFixed(2)} adicionado ao cliente.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.amber[800]),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChipStatus(status: statusPag),
                      ChipStatus(status: statusRet, prefixo: 'Entrega: '),
                    ],
                  ),
                  if (obs != null && obs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Observações:',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(obs),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Itens do pedido
          _TituloSecao(titulo: 'Itens do Pedido'),
          Card(
            child: itens.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum item registrado.'),
                  )
                : Column(
                    children: [
                      _LinhaTabela(
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
                            _LinhaTabela(
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

          // Pagamentos recebidos
          _TituloSecao(titulo: 'Pagamentos'),
          Card(
            child: pagamentosReais.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum pagamento recebido ainda.'),
                  )
                : Column(
                    children: pagamentosReais.map((pag) {
                      final dataPag =
                          _formatarDataHora(pag['criado_em']) ?? '—';
                      final forma = pag['forma_pagamento'] as String? ?? '—';
                      final valor = _toDouble(pag['valor_pago']);
                      return ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(forma),
                        subtitle: Text(dataPag),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${valor.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              tooltip: 'Ações',
                              onSelected: (valor) {
                                if (valor == 'editar') onEditarPagamento(pag);
                                if (valor == 'excluir') onExcluirPagamento(pag);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'excluir',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline,
                                        color:
                                            Theme.of(context).colorScheme.error),
                                    title: Text('Excluir',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // Entregas do pedido
          _TituloSecao(titulo: 'Entregas'),
          Card(
            child: retiradas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma entrega registrada ainda.'),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < retiradas.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _BlocoRetirada(
                          retirada: retiradas[i],
                          nomesPorProduto: nomesPorProduto,
                        ),
                      ],
                    ],
                  ),
          ),

          // Botão de registrar pagamento
          if (podePagar) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: salvando ? null : onRegistrarPagamento,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Registrar Pagamento'),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: salvando ? null : onEmitirPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Emitir PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _TituloSecao extends StatelessWidget {
  final String titulo;
  const _TituloSecao({required this.titulo});

  @override
  Widget build(BuildContext context) {
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
}

class _BlocoRetirada extends StatelessWidget {
  final Map<String, dynamic> retirada;
  final Map<int, String> nomesPorProduto;

  const _BlocoRetirada({
    required this.retirada,
    required this.nomesPorProduto,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = _formatarDataHora(retirada['data_retirada']) ?? '—';
    final local = retirada['local_saida'] as String? ?? '—';
    final motorista = retirada['motorista'] as String?;
    final placa = retirada['placa_veiculo'] as String?;

    final itens = (retirada['itens_retirada'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final temVeiculo = (motorista != null && motorista.isNotEmpty) ||
        (placa != null && placa.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: local de saída + data
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                local,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                data,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Itens retirados
          ...itens.map((item) {
            final prodId = item['produto_id'] as int?;
            final nome = prodId != null ? nomesPorProduto[prodId] : null;
            final qtd = item['quantidade'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(nome ?? '—', style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '${qtd}x',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),

          // Veículo (quando informado)
          if (temVeiculo) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (motorista != null && motorista.isNotEmpty) motorista,
                        if (placa != null && placa.isNotEmpty) placa,
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaTabela extends StatelessWidget {
  final List<String> cells;
  final List<int> flex;
  final bool isHeader;

  const _LinhaTabela({
    required this.cells,
    required this.flex,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ── Funções utilitárias ───────────────────────────────────────────────────────

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

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
