import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';

/// Uma parcela já registrada no `ModalPagamento` — mostra a forma (com nº de
/// parcelas), a conta (ou "pendente"), o pagador (se houver), o valor e um
/// botão para removê-la. Pagamentos posteriores (crediário) aparecem como
/// "a receber" em laranja, com ícone de relógio.
class LinhaParcela extends StatelessWidget {
  /// Mapa da parcela: `{forma, valor, pagamentoPosterior, parcelas, conta?,
  /// nomePagador?}` — o mesmo formato montado pelo `ModalPagamento`.
  final Map<String, dynamic> pagamento;
  final VoidCallback onRemover;

  const LinhaParcela({
    super.key,
    required this.pagamento,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = pagamento;
    final isPosterior = p['pagamentoPosterior'] as bool;
    // Escambo (troca): tem kg de produção e não tem conta.
    final escamboKg = (p['escamboQuantidade'] as num?)?.toDouble();
    final isEscambo = escamboKg != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Ícone diferente para pagamentos posteriores (crediário)
          isPosterior
              ? Icon(
                  Icons.access_time,
                  size: 16,
                  color: CoresSemanticas.aviso,
                )
              : const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: CoresSemanticas.sucesso,
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p['parcelas'] as int? ?? 1) > 1
                      ? '${p['forma']} (${p['parcelas']}x)'
                      : p['forma'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: isPosterior ? CoresSemanticas.aviso : null,
                  ),
                ),
                if (isEscambo)
                  Text(
                    'Pimenta: ${formatarQuantidade(escamboKg)} kg',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else if (p['conta'] != null)
                  Text(
                    'Conta: ${p['conta']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else if (!isPosterior)
                  Text(
                    'Conta: pendente',
                    style: TextStyle(
                      fontSize: 11,
                      color: CoresSemanticas.aviso,
                    ),
                  ),
                if (p['nomePagador'] != null)
                  Text(
                    'Pago por: ${p['nomePagador']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isPosterior)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'a receber',
                style: TextStyle(
                  fontSize: 11,
                  color: CoresSemanticas.aviso,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Text(
            formatarMoeda(p['valor'] as double),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPosterior ? CoresSemanticas.aviso : null,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemover,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 15,
                color: CoresSemanticas.erro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
