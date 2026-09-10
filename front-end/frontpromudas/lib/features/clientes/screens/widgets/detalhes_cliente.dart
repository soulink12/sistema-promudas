import 'package:flutter/material.dart';
import '../../../../core/widgets/chip_status.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/cpf_cnpj.dart';
import '../../../../core/utils/formatadores.dart';

class DetalhesCliente extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final List<Map<String, dynamic>> pedidosCliente;
  final bool carregandoPedidos;
  final VoidCallback onIniciarEdicao;
  final void Function(Map<String, dynamic> pedido) onTapPedido;
  final VoidCallback onVerTodosPedidos;

  const DetalhesCliente({
    super.key,
    required this.cliente,
    required this.pedidosCliente,
    required this.carregandoPedidos,
    required this.onIniciarEdicao,
    required this.onTapPedido,
    required this.onVerTodosPedidos,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = cliente;
    final nome = capitalizarNome(c['nome'] as String? ?? '');
    final cpfCnpj = c['cpf_cnpj'] as String?;
    final saldoCredito = paraDouble(c['saldo_credito']);
    final pendentes = pedidosCliente.where((p) {
      final s = p['status_pagamento'] as String? ?? '';
      return s == 'Pendente' || s == 'Parcial';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card do cliente ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          _iniciais(nome),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${c['id']}',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar cliente',
                        onPressed: onIniciarEdicao,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  ...[
                    _secao(context, 'Identificação', [
                      (
                        'CPF / CNPJ',
                        cpfCnpj != null && cpfCnpj.isNotEmpty
                            ? formatarCpfCnpj(cpfCnpj)
                            : null,
                      ),
                      ('Inscrição Estadual', c['inscricao_estadual']),
                    ]),
                    _secao(context, 'Contato', [
                      ('Telefone', formatarTelefone(c['telefone_1'] as String?)),
                      ('Telefone 2', formatarTelefone(c['telefone_2'] as String?)),
                      ('E-mail', c['email']),
                    ]),
                    _secao(context, 'Endereço', [
                      ('CEP', formatarCep(c['cep'] as String?)),
                      ('Logradouro', _emMaiusculas(c['logradouro'])),
                      ('Número', _emMaiusculas(c['numero'])),
                      ('Bairro', _emMaiusculas(c['bairro'])),
                      ('Cidade', _emMaiusculas(c['cidade'])),
                      ('Estado', _emMaiusculas(c['estado'])),
                    ]),
                    _secao(context, 'Sistema', [
                      ('Cadastrado em', _formatarData(c['criado_em'])),
                    ]),
                  ].whereType<Widget>(),
                ],
              ),
            ),
          ),

          // ── Crédito disponível ─────────────────────────────────────────
          if (saldoCredito > 0) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.savings_outlined,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CRÉDITO DISPONÍVEL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatarMoeda(saldoCredito),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Pedidos pendentes ──────────────────────────────────────────
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'PEDIDOS PENDENTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              if (!carregandoPedidos && pendentes.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: CoresSemanticas.aviso.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: CoresSemanticas.aviso.withAlpha(120),
                    ),
                  ),
                  child: Text(
                    '${pendentes.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CoresSemanticas.aviso,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (carregandoPedidos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pendentes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum pedido com pagamento pendente.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            )
          else
            Card(
              child: Column(
                children: pendentes.map((p) {
                  final numero = formatarNumeroPedido(p);
                  final total = paraDouble(p['valor_total']);
                  final status = p['status_pagamento'] as String? ?? 'Pendente';
                  final data = _formatarData(p['criado_em']) ?? '—';
                  final pagamentos = (p['pagamentos'] as List? ?? []);
                  final totalPagoReal = pagamentos.fold<double>(0.0, (
                    soma,
                    pag,
                  ) {
                    final isPosterior =
                        (pag as Map)['pagamento_posterior'] == true;
                    return isPosterior
                        ? soma
                        : soma + paraDouble(pag['valor_pago']);
                  });
                  final valorPendente = (total - totalPagoReal).clamp(
                    0.0,
                    total,
                  );

                  return Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: Container(
                          // Sem tamanho fixo: a caixa expande para caber o
                          // número (ex.: "#1234"), com um mínimo para manter
                          // o formato de badge nos números curtos.
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              numero,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Valor pendente do pedido $numero é ${formatarMoeda(valorPendente)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          data,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: ChipStatus(status: status),
                        onTap: () => onTapPedido(p),
                      ),
                      if (p != pendentes.last) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onVerTodosPedidos,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver todos os pedidos'),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

// Endereço é exibido todo em maiúsculas (padrão de etiqueta/correspondência).
String? _emMaiusculas(dynamic valor) {
  final texto = valor?.toString().trim() ?? '';
  return texto.isEmpty ? null : texto.toUpperCase();
}

Widget? _secao(
  BuildContext context,
  String titulo,
  List<(String, dynamic)> campos,
) {
  final preenchidos = campos
      .where((f) => f.$2 != null && f.$2.toString().isNotEmpty)
      .toList();
  if (preenchidos.isEmpty) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 10),
      ...preenchidos.map((f) => _linha(context, f.$1, f.$2)),
      const SizedBox(height: 20),
    ],
  );
}

Widget _linha(BuildContext context, String label, dynamic valor) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(valor.toString(), style: const TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

// ── Funções utilitárias ─────────────────────────────────────────────────────

String _iniciais(String nome) {
  final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}


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
