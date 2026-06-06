import 'package:flutter/material.dart';

class DetalhesAppBar extends StatelessWidget {
  final Map<String, dynamic>? clienteSelecionado;
  final VoidCallback? onTap;

  const DetalhesAppBar({
    Key? key,
    required this.clienteSelecionado,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Se não houver cliente selecionado, não renderiza nada
    if (clienteSelecionado == null) {
      return const SizedBox.shrink();
    }

    final isVendaDireta = clienteSelecionado!['id'] == 1;

    return InkWell(
      onTap: onTap, // Permite clicar para pesquisar/mudar o cliente
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              clienteSelecionado!['nome'] ?? '',
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isVendaDireta
                  ? 'Venda Direta / Balcão'
                  : 'ID: ${clienteSelecionado!['id']} • CPF: ${clienteSelecionado!['cpf']} • Tel: ${clienteSelecionado!['telefone']}',
              style: const TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.normal, 
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}