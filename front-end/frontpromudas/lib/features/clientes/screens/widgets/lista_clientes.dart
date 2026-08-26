import 'package:flutter/material.dart';
import '../../../../core/utils/cpf_cnpj.dart';
import '../../../../core/utils/formatadores.dart';

class ListaClientes extends StatelessWidget {
  final List<Map<String, dynamic>> clientes;
  final String textoBusca;
  final void Function(Map<String, dynamic>) onSelecionarCliente;

  const ListaClientes({
    super.key,
    required this.clientes,
    required this.textoBusca,
    required this.onSelecionarCliente,
  });

  @override
  Widget build(BuildContext context) {
    if (clientes.isEmpty) {
      return Center(
        child: Text(
          textoBusca.isEmpty
              ? 'Nenhum cliente cadastrado.'
              : 'Nenhum cliente encontrado.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: clientes.length,
      separatorBuilder: (context, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = clientes[index];
        final nome = capitalizarNome(c['nome'] as String? ?? '');
        final cpf = c['cpf_cnpj'] as String?;
        final tel = c['telefone_1'] as String?;
        final subtitulo = [
          if (cpf != null && cpf.isNotEmpty) formatarCpfCnpj(cpf),
          if (tel != null && tel.isNotEmpty) tel,
        ].join(' • ');
        final cs = Theme.of(context).colorScheme;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(
              _iniciais(nome),
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(nome),
          subtitle: subtitulo.isNotEmpty ? Text(subtitulo) : null,
          onTap: () => onSelecionarCliente(c),
        );
      },
    );
  }
}

String _iniciais(String nome) {
  final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}
