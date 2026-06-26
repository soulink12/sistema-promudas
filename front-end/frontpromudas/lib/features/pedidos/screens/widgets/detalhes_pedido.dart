import 'package:flutter/material.dart';
import '../../../../core/widgets/chip_status.dart';
import '../../../../core/widgets/seletor_data_hora.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';
import 'titulo_secao.dart';
import 'linha_tabela.dart';
import 'linha_pagamento.dart';
import 'bloco_entrega.dart';

class DetalhesPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final bool salvando;
  final VoidCallback onVoltar;
  final VoidCallback onRegistrarPagamento;
  final VoidCallback onEmitirPdf;
  final VoidCallback onEditar;
  // Exclui o pedido (soft-delete) após confirmação
  final VoidCallback onExcluir;
  final VoidCallback onTapCliente;
  // Recebe a nova data/hora escolhida para o pedido (data_pedido)
  final void Function(DateTime novaData) onEditarData;
  // Abre o fluxo de troca da temporada do pedido (numeração 26-1, 27-1…)
  final VoidCallback onEditarTemporada;
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
    required this.onExcluir,
    required this.onTapCliente,
    required this.onEditarData,
    required this.onEditarTemporada,
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
              // Número do pedido (temporada) — clicável para trocar a temporada
              InkWell(
                onTap: onEditarTemporada,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pedido ${formatarNumeroPedido(pedido)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Opções do pedido',
                onSelected: (valor) {
                  switch (valor) {
                    case 'editar':
                      onEditar();
                      break;
                    case 'temporada':
                      onEditarTemporada();
                      break;
                    case 'excluir':
                      onExcluir();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar pedido'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'temporada',
                    child: ListTile(
                      leading: Icon(Icons.event_outlined),
                      title: Text('Editar temporada do pedido'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      title: Text('Excluir pedido',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
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
                                      ? CoresSemanticas.desconto
                                      : CoresSemanticas.acrescimo),
                            ),
                          ],
                          if (saldoCredito > 0.005) ...[
                            const SizedBox(height: 4),
                            Text(
                              'A receber: ${formatarMoeda(saldoCredito)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CoresSemanticas.aviso),
                            ),
                          ],
                          if (totalPagoReal > total + 0.01) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 14, color: CoresSemanticas.aviso),
                                const SizedBox(width: 4),
                                Text(
                                  'Crédito de ${formatarMoeda(totalPagoReal - total)} adicionado ao cliente.',
                                  style: const TextStyle(
                                      fontSize: 12, color: CoresSemanticas.aviso),
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
          const TituloSecao(titulo: 'Itens do Pedido'),
          Card(
            child: itens.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum item registrado.'),
                  )
                : Column(
                    children: [
                      const LinhaTabela(
                        isHeader: true,
                        cells: ['Produto', 'Qtd.', 'Preço Unit.', 'Total'],
                        flex: [4, 1, 2, 2],
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
                            LinhaTabela(
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
          const TituloSecao(titulo: 'Pagamentos'),
          Card(
            child: pagamentosReais.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum pagamento recebido ainda.'),
                  )
                : Column(
                    children: pagamentosReais
                        .map((pag) => LinhaPagamento(
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
          const TituloSecao(titulo: 'Entregas'),
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
                        BlocoEntrega(
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

// ── Funções utilitárias ───────────────────────────────────────────────────────

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

