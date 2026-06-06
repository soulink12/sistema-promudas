import 'package:flutter/material.dart';

class FormularioVendaWidget extends StatelessWidget {
  // Recebe a lista de itens da tela principal
  final List<Map<String, dynamic>> carrinho;
  // Callback para avisar a tela principal qual item deve ser apagado
  final Function(Map<String, dynamic>) onRemoverItem;

  const FormularioVendaWidget({
    super.key,
    required this.carrinho,
    required this.onRemoverItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Itens da Venda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(),

        // Verifica a variável local "carrinho"
        if (carrinho.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Nenhum produto adicionado ainda.\nUtilize a barra de pesquisa no rodapé.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Variedade / Produto', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Qtd.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Preço Unit.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  // Mapeia os itens recebidos pela tela principal
                  rows: carrinho.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text('#${item['id']}')),
                        DataCell(Text('${item['nome']}')),
                        DataCell(Text('${item['quantidade']}')),
                        DataCell(Text('R\$ ${item['preco'].toStringAsFixed(2)}')),
                        DataCell(
                          Text(
                            'R\$ ${item['total'].toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Remover item',
                            onPressed: () {
                              // Aqui está a mágica:
                              // Em vez de dar setState aqui, ele "grita" pra tela principal
                              onRemoverItem(item);
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}