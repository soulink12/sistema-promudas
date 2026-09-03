import 'package:flutter/material.dart';
import '../../../../core/widgets/chip_status.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';
import '../../../../core/utils/status_orcamento.dart';
import '../../../pedidos/screens/widgets/titulo_secao.dart';
import '../../../pedidos/screens/widgets/linha_tabela.dart';

class DetalhesOrcamento extends StatelessWidget {
  final Map<String, dynamic> orcamento;
  final bool salvando;
  final VoidCallback onVoltar;
  final VoidCallback onEmitirPdf;
  final VoidCallback onEnviarEmail;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onAprovar;
  final VoidCallback onRecusar;
  final VoidCallback onTapCliente;
  // Só chamado quando o orçamento já foi aprovado (pedido_id preenchido).
  final VoidCallback onVerPedidoGerado;

  const DetalhesOrcamento({
    super.key,
    required this.orcamento,
    required this.salvando,
    required this.onVoltar,
    required this.onEmitirPdf,
    required this.onEnviarEmail,
    required this.onEditar,
    required this.onExcluir,
    required this.onAprovar,
    required this.onRecusar,
    required this.onTapCliente,
    required this.onVerPedidoGerado,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeCliente = capitalizarNome(orcamento['clientes']?['nome'] as String? ?? '—');
    final total = _toDouble(orcamento['valor_total']);
    final ajuste = _toDouble(orcamento['ajuste']);
    final data = formatarDataHora(orcamento['data_orcamento'] ?? orcamento['criado_em']);
    final status = orcamento['status'] as String? ?? 'Pendente';
    final pendente = status == 'Pendente';
    final obs = orcamento['observacoes'] as String?;
    final pedidoId = orcamento['pedido_id'] as int?;

    final itens = (orcamento['itens_orcamento'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final clienteEmail = orcamento['clientes']?['email'] as String?;
    final temEmail = clienteEmail != null && clienteEmail.isNotEmpty;

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
                'Orçamento ${formatarNumeroOrcamento(orcamento)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Opções do orçamento',
                onSelected: (valor) {
                  switch (valor) {
                    case 'editar':
                      onEditar();
                      break;
                    case 'excluir':
                      onExcluir();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'editar',
                    enabled: pendente,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined,
                          color: pendente ? null : Theme.of(context).disabledColor),
                      title: const Text('Editar orçamento'),
                      subtitle: pendente ? null : Text(status),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: cs.error),
                      title: Text('Excluir orçamento', style: TextStyle(color: cs.error)),
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
                        child: InkWell(
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
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 20, color: cs.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatarMoeda(total),
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: cs.primary),
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(data,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ChipStatus(status: status, corOverride: corStatusOrcamento(status)),
                  if (obs != null && obs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Observações:',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(obs),
                  ],
                ],
              ),
            ),
          ),

          // Aprovado: link para o pedido gerado
          if (status == 'Aprovado' && pedidoId != null) ...[
            const SizedBox(height: 12),
            Card(
              color: CoresSemanticas.sucesso.withAlpha(20),
              child: ListTile(
                leading: Icon(Icons.task_alt, color: CoresSemanticas.sucesso),
                title: const Text('Convertido em pedido'),
                subtitle: const Text('Este orçamento deu origem a um pedido de verdade.'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: onVerPedidoGerado,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Itens do orçamento
          const TituloSecao(titulo: 'Itens do Orçamento'),
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
                        final nomeProduto = item['produtos']?['nome'] as String? ?? '—';
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

          // Aprovar / Recusar — só enquanto pendente. Recusar à esquerda,
          // Aprovar à direita; cada um pede confirmação antes de agir (o
          // diálogo fica na tela que possui a lógica, que injeta esses callbacks).
          if (pendente) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: salvando ? null : onRecusar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Recusar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: salvando ? null : onAprovar,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aprovar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CoresSemanticas.sucesso,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: salvando ? null : onEmitirPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Emitir PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tooltip(
                  message: temEmail ? '' : 'Cadastre o e-mail do cliente para poder enviar',
                  child: OutlinedButton.icon(
                    onPressed: (salvando || !temEmail) ? null : onEnviarEmail,
                    icon: const Icon(Icons.mail_outlined),
                    label: const Text('Enviar por E-mail'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

double _toDouble(dynamic v) => v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
