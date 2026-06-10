import 'package:flutter/material.dart';
import 'campo_busca_cliente.dart';

/// Barra de filtro por cliente para telas de listagem (pedidos, entregas).
///
/// Quando nenhum cliente está selecionado, mostra o campo de busca embutido
/// ([CampoBuscaCliente]). Com um filtro ativo, mostra um card com o nome do
/// cliente e um botão para remover o filtro. Já inclui o espaçamento inferior,
/// então basta posicioná-lo acima do conteúdo da lista.
class PesquisaClienteLista extends StatelessWidget {
  final Map<String, dynamic>? clienteSelecionado;
  final ValueChanged<Map<String, dynamic>> onSelecionado;
  final VoidCallback onLimpar;
  final String labelText;
  final String hintText;

  const PesquisaClienteLista({
    super.key,
    required this.clienteSelecionado,
    required this.onSelecionado,
    required this.onLimpar,
    this.labelText = 'Filtrar por cliente',
    this.hintText = 'Buscar por nome, CPF ou telefone',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: clienteSelecionado == null
              ? CampoBuscaCliente(
                  labelText: labelText,
                  hintText: hintText,
                  onSelecionado: onSelecionado,
                )
              : Card(
                  child: ListTile(
                    leading: Icon(Icons.person_outline, color: cs.primary),
                    title: Text(
                      clienteSelecionado!['nome'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remover filtro',
                      onPressed: onLimpar,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
