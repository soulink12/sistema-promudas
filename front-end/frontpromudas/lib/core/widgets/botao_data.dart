import 'package:flutter/material.dart';

class BotaoData extends StatelessWidget {
  final String label;
  final String valor;
  final bool selecionado;
  final VoidCallback onTap;
  final VoidCallback? onLimpar;

  const BotaoData({
    super.key,
    required this.label,
    required this.valor,
    required this.selecionado,
    required this.onTap,
    this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(
          color: selecionado ? cs.primary : cs.outline,
        ),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: selecionado ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 13,
                    color: selecionado ? cs.primary : cs.onSurfaceVariant,
                    fontWeight:
                        selecionado ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onLimpar != null)
            GestureDetector(
              onTap: onLimpar,
              child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
