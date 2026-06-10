import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/campo_busca_cliente.dart';
import 'widgets/card_retirada.dart';

/// Consulta (somente leitura) das retiradas já registradas.
class TelaConsultaRetiradas extends StatefulWidget {
  const TelaConsultaRetiradas({super.key});

  @override
  State<TelaConsultaRetiradas> createState() => _TelaConsultaRetiradasState();
}

class _TelaConsultaRetiradasState extends State<TelaConsultaRetiradas> {
  List<Map<String, dynamic>> _retiradas = [];
  bool _carregando = false;
  Map<String, dynamic>? _clienteSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarRetiradas();
  }

  Future<void> _carregarRetiradas() async {
    setState(() => _carregando = true);
    try {
      final params = <String, dynamic>{};
      if (_clienteSelecionado != null) {
        params['cliente'] = _clienteSelecionado!['nome'];
      }

      final response = await ApiService.dio.get(
        '/retiradas',
        queryParameters: params.isEmpty ? null : params,
      );

      final lista = (response.data as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _retiradas = lista;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar retiradas. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Consulta de Retiradas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _clienteSelecionado == null
                ? CampoBuscaCliente(
                    labelText: 'Filtrar por cliente',
                    hintText: 'Buscar por nome, CPF ou telefone',
                    onSelecionado: (c) {
                      setState(() => _clienteSelecionado = c);
                      _carregarRetiradas();
                    },
                  )
                : Card(
                    child: ListTile(
                      leading: Icon(Icons.person_outline, color: cs.primary),
                      title: Text(
                        _clienteSelecionado!['nome'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Remover filtro',
                        onPressed: () {
                          setState(() => _clienteSelecionado = null);
                          _carregarRetiradas();
                        },
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _retiradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: cs.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma retirada registrada.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregarRetiradas,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _retiradas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              CardRetirada(retirada: _retiradas[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
