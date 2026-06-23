import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../cheques/screens/cheques_a_depositar_screen.dart';
import '../../pagamentos/screens/pagamentos_sem_conta_screen.dart';

/// Centro de notificações — agrega todas as pendências do sistema em um só lugar.
/// Hoje: cheques a depositar e pagamentos sem conta. Cada tipo é um card com a
/// contagem; novos tipos entram aqui como mais cards.
class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  int _chequesADepositar = 0;
  int _pagamentosSemConta = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  /// Carrega as contagens de cada pendência. Falha silenciosa por tipo — o badge
  /// apenas não aparece se aquele endpoint falhar.
  Future<void> _carregar() async {
    try {
      final r = await ApiService.dio.get('/cheques/a-depositar');
      if (mounted) setState(() => _chequesADepositar = (r.data as List).length);
    } catch (_) {}
    try {
      final r = await ApiService.dio.get('/pagamentos/pendentes-conta');
      if (mounted) setState(() => _pagamentosSemConta = (r.data as List).length);
    } catch (_) {}
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    _carregar(); // pode ter mudado
  }

  @override
  Widget build(BuildContext context) {
    final semPendencias = _chequesADepositar == 0 && _pagamentosSemConta == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (semPendencias)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Nenhuma pendência no momento.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          _CardNotificacao(
            icon: Icons.account_balance_outlined,
            titulo: 'Cheques a depositar',
            descricao:
                'Cheques recebidos que ainda não foram depositados. Registre o depósito de cada um.',
            badge: _chequesADepositar,
            onTap: () => _abrir(const TelaChequesADepositar()),
          ),
          const SizedBox(height: 12),
          _CardNotificacao(
            icon: Icons.account_balance_wallet_outlined,
            titulo: 'Pagamentos sem conta',
            descricao:
                'Pagamentos sem conta definida (ex: dinheiro). Defina a conta de cada um.',
            badge: _pagamentosSemConta,
            onTap: () => _abrir(const TelaPagamentosSemConta()),
          ),
        ],
      ),
    );
  }
}

class _CardNotificacao extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descricao;
  final int badge;
  final VoidCallback onTap;

  const _CardNotificacao({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(descricao,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
