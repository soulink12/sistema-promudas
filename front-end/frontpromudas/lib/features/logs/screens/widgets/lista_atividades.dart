import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';
import 'log_formatadores.dart';

class ListaAtividades extends StatelessWidget {
  final List<Map<String, dynamic>> atividades;
  final bool carregandoMais;
  final bool podeCarregarMais;
  final VoidCallback onCarregarMais;
  final void Function(Map<String, dynamic> atividade) onSelecionar;

  const ListaAtividades({
    super.key,
    required this.atividades,
    required this.carregandoMais,
    required this.podeCarregarMais,
    required this.onCarregarMais,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    if (atividades.isEmpty) {
      return const Center(child: Text('Nenhuma atividade encontrada.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: atividades.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == atividades.length) {
          return _buildRodape(context);
        }
        final atividade = atividades[index];
        final usuario = atividade['usuarios']?['nome'] as String? ?? 'Sistema';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_iconePara(atividade['entidade'] as String?),
                color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
          ),
          title: Text(rotuloEvento(
              atividade['entidade'] as String?, atividade['acao'] as String?)),
          subtitle: Text('$usuario · ${formatarDataHora(atividade['criado_em'])}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelecionar(atividade),
        );
      },
    );
  }

  Widget _buildRodape(BuildContext context) {
    if (!podeCarregarMais) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: carregandoMais
            ? const CircularProgressIndicator()
            : OutlinedButton(
                onPressed: onCarregarMais,
                child: const Text('Carregar mais'),
              ),
      ),
    );
  }

  IconData _iconePara(String? entidade) {
    switch (entidade) {
      case 'pedido':
        return Icons.receipt_long_outlined;
      case 'orcamento':
        return Icons.description_outlined;
      case 'cliente':
        return Icons.person_outline;
      case 'produto':
        return Icons.eco_outlined;
      case 'pagamento':
        return Icons.payments_outlined;
      case 'entrega':
        return Icons.local_shipping_outlined;
      case 'cheque':
        return Icons.receipt_outlined;
      case 'forma_pagamento':
        return Icons.credit_card_outlined;
      case 'temporada':
        return Icons.calendar_month_outlined;
      default:
        return Icons.history;
    }
  }
}

/// Cor usada no ícone/realce conforme a ação (só decorativo).
Color corDaAcao(BuildContext context, String? acao) {
  switch (acao) {
    case 'exclusao':
      return CoresSemanticas.erro;
    case 'aprovacao':
      return CoresSemanticas.sucesso;
    case 'recusa':
      return CoresSemanticas.erro;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
