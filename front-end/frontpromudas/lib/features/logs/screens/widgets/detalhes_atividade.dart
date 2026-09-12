import 'package:flutter/material.dart';
import '../../../../core/utils/formatadores.dart';
import 'log_formatadores.dart';

class DetalhesAtividade extends StatelessWidget {
  final Map<String, dynamic> atividade;
  final VoidCallback onVoltar;

  /// true enquanto o detalhe completo (GET /logs/:id, com snapshot_anterior/
  /// diferencas) ainda está sendo buscado — o resumo da listagem não tem
  /// esses campos, então sem isso apareceria "sem evento anterior" por um
  /// instante antes da resposta real chegar.
  final bool carregandoDiferencas;

  /// true quando a busca do detalhe completo falhou (rede/servidor) — sem
  /// isso, o erro caía no mesmo texto de "sem evento anterior" usado para
  /// criação, confundindo falha de rede com ausência real de histórico.
  final bool erroDiferencas;

  const DetalhesAtividade({
    super.key,
    required this.atividade,
    required this.onVoltar,
    this.carregandoDiferencas = false,
    this.erroDiferencas = false,
  });

  @override
  Widget build(BuildContext context) {
    final usuario = atividade['usuarios']?['nome'] as String? ?? 'Sistema';
    final evento = rotuloEvento(
        atividade['entidade'] as String?, atividade['acao'] as String?);
    final entidadeId = atividade['entidade_id'];
    final snapshot = atividade['snapshot'];
    final snapshotAnterior = atividade['snapshot_anterior'];
    final diferencasRaw = atividade['diferencas'];
    final diferencas = diferencasRaw is List
        ? diferencasRaw.cast<Map<String, dynamic>>()
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onVoltar,
        ),
        title: const Text('Detalhes do registro'),
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
                  Text(evento,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _linha(context, 'Usuário', usuario),
                  _linha(context, 'Quando', formatarDataHora(atividade['criado_em'])),
                  if (entidadeId != null)
                    _linha(context, 'ID do registro', '$entidadeId'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._blocoMudancas(context, snapshotAnterior, diferencas, carregandoDiferencas, erroDiferencas),
          const SizedBox(height: 16),
          _tituloSecao(context, 'ESTADO COMPLETO APÓS O EVENTO'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: snapshot == null
                  ? const Text('Sem dados registrados.')
                  : SelectableText(
                      formatarSnapshot(snapshot),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Bloco "O que mudou": mostra a diferença campo a campo em relação ao
  // evento anterior desta mesma entidade (backend calcula em logService.js).
  // Sem evento anterior (ex.: criação), não há o que comparar.
  List<Widget> _blocoMudancas(
    BuildContext context,
    dynamic snapshotAnterior,
    List<Map<String, dynamic>>? diferencas,
    bool carregando,
    bool erro,
  ) {
    if (carregando) {
      return [
        _tituloSecao(context, 'O QUE MUDOU'),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Carregando...'),
              ],
            ),
          ),
        ),
      ];
    }

    if (erro) {
      return [
        _tituloSecao(context, 'O QUE MUDOU'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Não foi possível carregar a comparação com o evento anterior.')),
              ],
            ),
          ),
        ),
      ];
    }

    if (snapshotAnterior == null || diferencas == null) {
      return [
        _tituloSecao(context, 'O QUE MUDOU'),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Sem evento anterior deste registro para comparar (provavelmente a criação).'),
          ),
        ),
      ];
    }

    if (diferencas.isEmpty) {
      return [
        _tituloSecao(context, 'O QUE MUDOU'),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nenhum campo mudou de valor neste evento.'),
          ),
        ),
      ];
    }

    return [
      _tituloSecao(context, 'O QUE MUDOU'),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final diferenca in diferencas) ...[
                Text(
                  rotuloCampo(diferenca['campo'] as String? ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                if (diferenca['tipo'] == 'lista')
                  _blocoListaDeItens(
                      context, (diferenca['itens'] as List).cast<Map<String, dynamic>>())
                else
                  _linhaDeParaTexto(context, diferenca['de'], diferenca['para'],
                      campo: diferenca['campo'] as String?),
                if (diferenca != diferencas.last) const Divider(height: 20),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  // Diff item a item de uma lista (itens_pedido/itens_orcamento) — cada
  // entrada já vem classificada pelo backend como adicionado/removido/alterado
  // (logService.js compara por produto, não por id da linha, porque toda
  // edição com itens apaga e recria as linhas no banco).
  Widget _blocoListaDeItens(BuildContext context, List<Map<String, dynamic>> itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entrada in itens) _linhaItemDiferenca(context, entrada),
      ],
    );
  }

  Widget _linhaItemDiferenca(BuildContext context, Map<String, dynamic> entrada) {
    final tipo = entrada['tipo'] as String?;
    final cores = Theme.of(context).colorScheme;

    if (tipo == 'adicionado') {
      final item = entrada['item'] as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('+ ${rotuloItem(item)} (${resumoItem(item)})',
            style: TextStyle(color: cores.primary)),
      );
    }
    if (tipo == 'removido') {
      final item = entrada['item'] as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('− ${rotuloItem(item)} (${resumoItem(item)})',
            style: TextStyle(color: cores.error)),
      );
    }
    // 'alterado'
    final depois = entrada['depois'] as Map<String, dynamic>;
    final camposAlterados =
        (entrada['camposAlterados'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotuloItem(depois)),
          for (final campo in camposAlterados)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: _linhaDeParaTexto(context, campo['de'], campo['para'],
                  rotulo: rotuloCampo(campo['campo'] as String? ?? ''),
                  campo: campo['campo'] as String?),
            ),
        ],
      ),
    );
  }

  Widget _linhaDeParaTexto(BuildContext context, dynamic de, dynamic para, {String? rotulo, String? campo}) {
    final estiloMonoespaco = const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4);
    return SelectableText.rich(
      TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          if (rotulo != null)
            TextSpan(
              text: '$rotulo: ',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          TextSpan(text: formatarValorDiferenca(de, campo), style: estiloMonoespaco.copyWith(
              color: Theme.of(context).colorScheme.error)),
          const TextSpan(text: '  →  '),
          TextSpan(text: formatarValorDiferenca(para, campo), style: estiloMonoespaco.copyWith(
              color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tituloSecao(BuildContext context, String texto) => Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      );

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
