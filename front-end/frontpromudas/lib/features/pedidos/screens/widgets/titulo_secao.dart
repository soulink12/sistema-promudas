import 'package:flutter/material.dart';

/// Rótulo de seção usado nos detalhes do pedido (ex.: "Itens do Pedido",
/// "Pagamentos", "Entregas"). Texto pequeno em caixa, na cor primária do tema.
class TituloSecao extends StatelessWidget {
  final String titulo;
  const TituloSecao({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
