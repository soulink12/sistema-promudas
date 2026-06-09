import 'package:flutter/material.dart';
import '../../../../core/widgets/campo_busca_cliente.dart';

/// Popup de busca de clientes exibido próximo à AppBar.
class BuscaClienteModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onClienteSelecionado;

  const BuscaClienteModal({
    super.key,
    required this.onClienteSelecionado,
  });

  @override
  State<BuscaClienteModal> createState() => _BuscaClienteModalState();
}

class _BuscaClienteModalState extends State<BuscaClienteModal> {
  // Evita dupla seleção quando onEditingComplete + onSubmitted disparam juntos
  bool _selecionado = false;

  void _confirmar(Map<String, dynamic> cliente) {
    if (_selecionado) return;
    _selecionado = true;
    widget.onClienteSelecionado(cliente);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecionar Cliente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          CampoBuscaCliente(
            autofocus: true,
            labelText: 'Digite Nome, CPF ou Telefone',
            onSelecionado: _confirmar,
          ),
        ],
      ),
    );
  }
}
