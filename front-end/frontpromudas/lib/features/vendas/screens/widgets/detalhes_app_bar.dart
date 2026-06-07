import 'package:flutter/material.dart';

/// Widget que exibe as informações do cliente selecionado na AppBar da tela de venda.
/// Ao ser tocado, dispara o callback [onTap] para abrir o modal de busca de clientes.
class DetalhesAppBar extends StatelessWidget {
  // Cliente atualmente vinculado à venda
  final Map<String, dynamic>? clienteSelecionado;
  // Ação executada ao tocar na área do cliente (normalmente abre o modal de busca)
  final VoidCallback? onTap;

  const DetalhesAppBar({
    Key? key,
    required this.clienteSelecionado,
    this.onTap,
  }) : super(key: key);

  /// Constrói o conteúdo da AppBar com nome e dados do cliente.
  /// Se o cliente for o consumidor padrão (id == 1), exibe "Venda Direta / Balcão"
  /// em vez dos dados pessoais. Se nenhum cliente estiver selecionado, não renderiza nada.
  @override
  Widget build(BuildContext context) {
    // Se não houver cliente selecionado, não renderiza nada
    if (clienteSelecionado == null) {
      return const SizedBox.shrink();
    }

    // Verifica se é venda direta (consumidor padrão sem CPF cadastrado)
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
            // Nome do cliente em destaque
            Text(
              clienteSelecionado!['nome'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            // Linha secundária: "Venda Direta" para consumidor padrão ou ID/CPF/Tel para clientes cadastrados
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