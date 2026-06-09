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
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(
          color: selecionado ? Colors.green : Colors.grey.shade400,
        ),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: selecionado ? Colors.green[700] : Colors.grey,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 13,
                    color: selecionado ? Colors.green[800] : Colors.grey,
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
              child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}
