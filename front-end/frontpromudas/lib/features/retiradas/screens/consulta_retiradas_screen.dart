import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../../core/widgets/dialog_confirmacao.dart';
import 'widgets/card_retirada.dart';
import 'widgets/modal_retirada.dart';

/// Consulta das entregas já registradas, com ações de editar e excluir.
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
            content: Text('Erro ao carregar entregas. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editarRetirada(Map<String, dynamic> retirada) async {
    final pedidoId = (retirada['pedidos'] as Map<String, dynamic>?)?['id'];
    if (pedidoId == null) return;

    // Busca o pedido completo (itens_pedido + retiradas) para calcular o saldo
    Map<String, dynamic> pedido;
    try {
      final response = await ApiService.dio.get('/pedidos/$pedidoId');
      pedido = Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar o pedido. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => ModalRetirada(
        pedido: pedido,
        retiradaParaEditar: retirada,
        onSalvo: () {
          Navigator.pop(context);
          _carregarRetiradas();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrega atualizada com sucesso.')),
          );
        },
      ),
    );
  }

  Future<void> _excluirRetirada(Map<String, dynamic> retirada) async {
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Excluir entrega',
      mensagem:
          'Tem certeza que deseja excluir esta entrega? O saldo dos produtos voltará a ficar disponível para entrega.',
      textoConfirmar: 'Excluir',
    );
    if (!confirmado) return;

    try {
      await ApiService.dio.delete('/retiradas/${retirada['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega excluída com sucesso.')),
      );
      _carregarRetiradas();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir entrega. Tente novamente.'),
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
      appBar: AppBar(title: const Text('Consulta de Entregas')),
      body: Column(
        children: [
          PesquisaClienteLista(
            clienteSelecionado: _clienteSelecionado,
            onSelecionado: (c) {
              setState(() => _clienteSelecionado = c);
              _carregarRetiradas();
            },
            onLimpar: () {
              setState(() => _clienteSelecionado = null);
              _carregarRetiradas();
            },
          ),
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
                              'Nenhuma entrega registrada.',
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
                          itemBuilder: (_, i) => CardRetirada(
                            retirada: _retiradas[i],
                            onEditar: () => _editarRetirada(_retiradas[i]),
                            onExcluir: () => _excluirRetirada(_retiradas[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
