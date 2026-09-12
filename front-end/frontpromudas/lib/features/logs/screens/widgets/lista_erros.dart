import 'package:flutter/material.dart';
import '../../../../core/theme/cores_semanticas.dart';
import '../../../../core/utils/formatadores.dart';

class ListaErros extends StatelessWidget {
  final List<Map<String, dynamic>> erros;
  final bool carregandoMais;
  final bool podeCarregarMais;
  final VoidCallback onCarregarMais;
  final void Function(Map<String, dynamic> erro) onSelecionar;

  const ListaErros({
    super.key,
    required this.erros,
    required this.carregandoMais,
    required this.podeCarregarMais,
    required this.onCarregarMais,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    if (erros.isEmpty) {
      return const Center(child: Text('Nenhum erro registrado. 🎉'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: erros.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == erros.length) return _buildRodape(context);
        final erro = erros[index];
        final rota = erro['rota'] as String?;
        final metodo = erro['metodo_http'] as String?;
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: CoresSemanticas.erro,
            child: Icon(Icons.error_outline, color: Colors.white, size: 20),
          ),
          title: Text(
            (erro['mensagem'] as String?) ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              formatarDataHora(erro['criado_em']),
              if (metodo != null && rota != null) '$metodo $rota',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelecionar(erro),
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
}
