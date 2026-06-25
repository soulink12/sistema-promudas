import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';

/// Linha de um pagamento na lista de detalhes do pedido — mostra forma, data,
/// pagador (se houver), status da nota fiscal e o menu de ações (editar, nota
/// fiscal, excluir).
class LinhaPagamento extends StatelessWidget {
  final Map<String, dynamic> pag;
  final void Function(Map<String, dynamic>) onEditar;
  final void Function(Map<String, dynamic>) onExcluir;
  final void Function(Map<String, dynamic>) onNota;

  const LinhaPagamento({
    super.key,
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
    // Escambo (troca): kg de produção recebidos; não tem conta.
    // Decimal vem como String no JSON — parse robusto.
    final escamboKg = pag['escambo_quantidade'] == null
        ? null
        : double.tryParse(pag['escambo_quantidade'].toString());
    final isEscambo = escamboKg != null;
    // Pagamento real sem conta = conta ainda pendente (ex: dinheiro/cheque).
    // Escambo não conta como "sem conta" (não é dinheiro).
    final contaPendente = !temConta && !posterior && !isEscambo;
    final nomePagador = pag['nome_pagador'] as String?;
    final temPagador = nomePagador != null && nomePagador.isNotEmpty;
    final cheques = (pag['cheques'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];

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
                          fontSize: 12, color: CoresSemanticas.aviso)),
                ],
                if (isEscambo) ...[
                  const SizedBox(height: 2),
                  Text('Pimenta: ${formatarQuantidade(escamboKg)} kg',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
                if (temPagador) ...[
                  const SizedBox(height: 2),
                  Text('Pago por: $nomePagador',
                      style: TextStyle(fontSize: 12, color: cs.primary)),
                ],
                ...cheques.map((c) {
                  final depositado =
                      c['depositado'] == true || c['data_deposito'] != null;
                  final cor = depositado
                      ? CoresSemanticas.sucesso
                      : CoresSemanticas.aviso;
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_textoCheque(c),
                        style: TextStyle(fontSize: 12, color: cor)),
                  );
                }),
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

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

/// Resumo de um cheque na linha de pagamento: identificação, valor e situação
/// (a depositar / depositado em dd/mm/aaaa).
String _textoCheque(Map<String, dynamic> c) {
  final numero = c['numero'] as String?;
  final banco = c['banco'] as String?;
  final partes = <String>['Cheque'];
  if (numero != null && numero.isNotEmpty) partes.add('nº $numero');
  if (banco != null && banco.isNotEmpty) partes.add(banco);
  var texto = '${partes.join(' ')} · ${formatarMoeda(_toDouble(c['valor']))}';
  final dep = c['data_deposito'];
  if (dep != null) {
    final dt = DateTime.tryParse(dep.toString())?.toLocal();
    texto += dt != null
        ? ' · depositado ${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : ' · depositado';
  } else {
    texto += ' · a depositar';
  }
  return texto;
}

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
      return CoresSemanticas.sucesso;
    case 'Rejeitada':
      return cs.error;
    case 'Processando':
      return CoresSemanticas.info;
    default: // Pendente
      return CoresSemanticas.aviso;
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
