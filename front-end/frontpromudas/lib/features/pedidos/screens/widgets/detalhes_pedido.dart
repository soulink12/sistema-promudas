import 'package:flutter/material.dart';
import '../../../../core/widgets/chip_status.dart';
import '../../../../core/widgets/seletor_data_hora.dart';
import '../../../../core/utils/formatadores.dart';

class DetalhesPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final bool salvando;
  final VoidCallback onVoltar;
  final VoidCallback onRegistrarPagamento;
  final VoidCallback onEmitirPdf;
  final VoidCallback onEditar;
  final VoidCallback onTapCliente;
  // Recebe a nova data/hora escolhida para o pedido (data_pedido)
  final void Function(DateTime novaData) onEditarData;
  final void Function(Map<String, dynamic> pagamento) onEditarPagamento;
  final void Function(Map<String, dynamic> pagamento) onExcluirPagamento;
  final void Function(Map<String, dynamic> pagamento) onNotaFiscalPagamento;

  const DetalhesPedido({
    super.key,
    required this.pedido,
    required this.salvando,
    required this.onVoltar,
    required this.onRegistrarPagamento,
    required this.onEmitirPdf,
    required this.onEditar,
    required this.onTapCliente,
    required this.onEditarData,
    required this.onEditarPagamento,
    required this.onExcluirPagamento,
    required this.onNotaFiscalPagamento,
  });

  @override
  Widget build(BuildContext context) {
    final nomeCliente = pedido['clientes']?['nome'] as String? ?? '—';
    final total = _toDouble(pedido['valor_total']);
    final ajuste = _toDouble(pedido['ajuste']);
    final dataPedidoRaw = pedido['data_pedido'] ?? pedido['criado_em'];
    final data = formatarDataHora(dataPedidoRaw);
    final statusPag = pedido['status_pagamento'] as String? ?? 'Pendente';
    final statusRet = pedido['status_entrega'] as String? ?? 'Pendente';
    final obs = pedido['observacoes'] as String?;

    final itens = (pedido['itens_pedido'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final todosPagamentos = (pedido['pagamentos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final entregas = (pedido['entregas'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Os itens da entrega não trazem o nome do produto — montamos o mapa
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
                            // Data/hora do pedido — clicável para editar (consulta)
                            InkWell(
                              onTap: () async {
                                final inicial = DateTime.tryParse(
                                            dataPedidoRaw?.toString() ?? '')
                                        ?.toLocal() ??
                                    DateTime.now();
                                final nova =
                                    await selecionarDataHora(context, inicial);
                                if (nova != null) onEditarData(nova);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(data,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit_calendar_outlined,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatarMoeda(total),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          if (ajuste != 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${ajuste < 0 ? 'Desconto' : 'Acréscimo'}: ${formatarMoeda(ajuste.abs())}',
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
                              'A receber: ${formatarMoeda(saldoCredito)}',
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
                                  'Crédito de ${formatarMoeda(totalPagoReal - total)} adicionado ao cliente.',
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
                                formatarMoeda(preco),
                                formatarMoeda(totalItem),
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
                    children: pagamentosReais
                        .map((pag) => _LinhaPagamento(
                              pag: pag,
                              onEditar: onEditarPagamento,
                              onExcluir: onExcluirPagamento,
                              onNota: onNotaFiscalPagamento,
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // Entregas do pedido
          _TituloSecao(titulo: 'Entregas'),
          Card(
            child: entregas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma entrega registrada ainda.'),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < entregas.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _BlocoEntrega(
                          entrega: entregas[i],
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

/// Linha de um pagamento na lista de detalhes do pedido — mostra forma, data,
/// pagador (se houver), status da nota fiscal e o menu de ações.
class _LinhaPagamento extends StatelessWidget {
  final Map<String, dynamic> pag;
  final void Function(Map<String, dynamic>) onEditar;
  final void Function(Map<String, dynamic>) onExcluir;
  final void Function(Map<String, dynamic>) onNota;

  const _LinhaPagamento({
    required this.pag,
    required this.onEditar,
    required this.onExcluir,
    required this.onNota,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final dataPag =
        formatarDataHora(pag['data_pagamento'] ?? pag['criado_em']);
    final formaBase = pag['forma_pagamento'] as String? ?? '—';
    final parcelas = pag['parcelas'] as int? ?? 1;
    final forma = parcelas > 1 ? '$formaBase ($parcelas' 'x)' : formaBase;
    final valor = _toDouble(pag['valor_pago']);
    final conta = pag['conta'] as String?;
    final temConta = conta != null && conta.isNotEmpty;
    final posterior = pag['pagamento_posterior'] == true;
    // Pagamento real sem conta = conta ainda pendente (ex: dinheiro/cheque)
    final contaPendente = !temConta && !posterior;
    final nomePagador = pag['nome_pagador'] as String?;
    final temPagador = nomePagador != null && nomePagador.isNotEmpty;

    final statusNota = pag['status_nota'] as String? ?? 'Pendente';
    final numeroNota = pag['numero_nota'] as String?;
    final dataNota = _formatarDataNota(pag['data_emissao_nota']);
    final corNota = _corStatusNota(statusNota, cs);
    final textoNota = _textoNota(statusNota, numeroNota, dataNota);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(Icons.payments_outlined, color: cs.onSurfaceVariant),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(forma,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15)),
                const SizedBox(height: 2),
                Text(dataPag,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (temConta) ...[
                  const SizedBox(height: 2),
                  Text('Conta: $conta',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ] else if (contaPendente) ...[
                  const SizedBox(height: 2),
                  Text('Conta: pendente',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[800])),
                ],
                if (temPagador) ...[
                  const SizedBox(height: 2),
                  Text('Pago por: $nomePagador',
                      style: TextStyle(fontSize: 12, color: cs.primary)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 13, color: corNota),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        textoNota,
                        style: TextStyle(
                            fontSize: 12,
                            color: corNota,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              formatarMoeda(valor),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: cs.onSurfaceVariant),
            tooltip: 'Ações',
            onSelected: (v) {
              if (v == 'editar') onEditar(pag);
              if (v == 'nota') onNota(pag);
              if (v == 'excluir') onExcluir(pag);
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
              const PopupMenuItem(
                value: 'nota',
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Nota fiscal'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'excluir',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: Text('Excluir', style: TextStyle(color: cs.error)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlocoEntrega extends StatelessWidget {
  final Map<String, dynamic> entrega;
  final Map<int, String> nomesPorProduto;

  const _BlocoEntrega({
    required this.entrega,
    required this.nomesPorProduto,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = formatarDataHora(entrega['data_entrega']);
    final local = entrega['local_entrega'] as String? ?? '—';
    final motorista = entrega['motorista'] as String?;
    final placa = entrega['placa_veiculo'] as String?;

    final itens = (entrega['itens_entrega'] as List? ?? [])
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

          // Itens entregues
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

/// Formata a data de emissão da nota (coluna só-data). Usa componentes UTC
/// para não deslocar o dia ao converter para o fuso local.
String? _formatarDataNota(dynamic valor) {
  if (valor == null) return null;
  final dt = DateTime.tryParse(valor.toString());
  if (dt == null) return null;
  final u = dt.toUtc();
  return '${u.day.toString().padLeft(2, '0')}/'
      '${u.month.toString().padLeft(2, '0')}/${u.year}';
}

Color _corStatusNota(String status, ColorScheme cs) {
  switch (status) {
    case 'Emitida':
      return Colors.green.shade700;
    case 'Rejeitada':
      return cs.error;
    case 'Processando':
      return Colors.blue.shade700;
    default: // Pendente
      return Colors.orange.shade800;
  }
}

String _textoNota(String status, String? numero, String? data) {
  if (status == 'Emitida') {
    final partes = <String>['Nota emitida'];
    if (numero != null && numero.isNotEmpty) partes.add('nº $numero');
    if (data != null) partes.add(data);
    return partes.join(' · ');
  }
  return 'Nota: $status';
}

