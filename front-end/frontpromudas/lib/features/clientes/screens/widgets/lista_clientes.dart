import 'package:flutter/material.dart';

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
    if (textoBusca.isEmpty) {
      return const Center(
        child: Text(
          'Digite para pesquisar clientes.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (clientes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum cliente encontrado.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: clientes.length,
      separatorBuilder: (context, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = clientes[index];
        final nome = c['nome'] as String? ?? '';
        final cpf = c['cpf_cnpj'] as String?;
        final tel = c['telefone_1'] as String?;
        final subtitulo = [
          if (cpf != null && cpf.isNotEmpty) cpf,
          if (tel != null && tel.isNotEmpty) tel,
        ].join(' • ');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green[100],
            child: Text(
              _iniciais(nome),
              style: TextStyle(
                  color: Colors.green[800], fontWeight: FontWeight.bold),
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
