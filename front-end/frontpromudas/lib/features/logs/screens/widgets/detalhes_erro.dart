import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';

class DetalhesErro extends StatelessWidget {
  final Map<String, dynamic> erro;
  final VoidCallback onVoltar;

  const DetalhesErro({
    super.key,
    required this.erro,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    final usuario = erro['usuarios']?['nome'] as String? ?? 'Sistema';
    final rota = erro['rota'] as String?;
    final metodo = erro['metodo_http'] as String?;
    final statusCode = erro['status_code'];
    final origem = erro['origem'] as String?;
    final stack = erro['stack'] as String?;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onVoltar,
        ),
        title: const Text('Detalhes do erro'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    (erro['mensagem'] as String?) ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  _linha(context, 'Quando', formatarDataHora(erro['criado_em'])),
                  _linha(context, 'Usuário', usuario),
                  _linha(context, 'Origem', origem ?? '—'),
                  if (metodo != null || rota != null)
                    _linha(context, 'Requisição', '${metodo ?? ''} ${rota ?? ''}'.trim()),
                  if (statusCode != null)
                    _linha(context, 'Status HTTP', '$statusCode'),
                ],
              ),
            ),
          ),
          if (stack != null) ...[
            const SizedBox(height: 16),
            Text(
              'STACK TRACE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  stack,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(BuildContext context, String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$rotulo: ',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }
}
