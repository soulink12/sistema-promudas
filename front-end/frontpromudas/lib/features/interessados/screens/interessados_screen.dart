import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/api_feedback.dart';
import '../../../core/widgets/pesquisa_cliente_lista.dart';
import '../../../core/widgets/dialog_confirmacao.dart';
import '../../clientes/screens/clientes_screen.dart';
import 'widgets/lista_interessados.dart';
import 'widgets/detalhes_interessado.dart';
import 'widgets/modal_interessado.dart';

/// Lista de Interessados: registro de clientes interessados em mudas ainda não
/// vendidas — à parte de pedido/orçamento, sem valor (só cliente + mudas +
/// quantidade). Mesmo padrão lista+detalhe de Orçamentos/Pedidos.
class TelaInteressados extends StatefulWidget {
  const TelaInteressados({super.key});

  @override
  State<TelaInteressados> createState() => _TelaInteressadosState();
}

class _TelaInteressadosState extends State<TelaInteressados> {
  List<Map<String, dynamic>> _interessados = [];
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  Map<String, dynamic>? _clienteFiltro;
  Map<String, dynamic>? _interessadoSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarInteressados();
  }

  Future<void> _carregarInteressados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final clienteNome = _clienteFiltro?['nome'] as String?;
      final params = <String, dynamic>{
        if (clienteNome != null && clienteNome.isNotEmpty) 'cliente': clienteNome,
      };
      final response = await ApiService.dio.get('/interessados', queryParameters: params);
      final dados = response.data as List;
      if (mounted) {
        setState(() {
          _interessados = dados
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os interessados.';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _recarregarSilencioso(int interessadoId) async {
    try {
      final response = await ApiService.dio.get('/interessados/$interessadoId');
      final atualizado = Map<String, dynamic>.from(response.data as Map);
      if (mounted) {
        setState(() {
          _interessadoSelecionado = atualizado;
          final idx = _interessados.indexWhere((i) => i['id'] == interessadoId);
          if (idx != -1) _interessados[idx] = atualizado;
        });
      }
    } catch (_) {
      // Falha silenciosa — mantém dados antigos
    }
  }

  void _selecionarClienteFiltro(Map<String, dynamic> cliente) {
    setState(() {
      _clienteFiltro = cliente;
      _interessadoSelecionado = null;
    });
    _carregarInteressados();
  }

  void _limparFiltro() {
    setState(() {
      _clienteFiltro = null;
      _interessadoSelecionado = null;
    });
    _carregarInteressados();
  }

  void _abrirDetalhesCliente(Map<String, dynamic> interessado) {
    final clienteId = interessado['clientes']?['id'] as int?;
    if (clienteId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaListaClientes(clienteInicialId: clienteId)),
    );
  }

  Future<void> _abrirModal({Map<String, dynamic>? interessadoParaEditar}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ModalInteressado(
        interessadoParaEditar: interessadoParaEditar,
        onSalvo: () async {
          await _carregarInteressados();
          if (interessadoParaEditar != null && mounted) {
            await _recarregarSilencioso(interessadoParaEditar['id'] as int);
          }
        },
      ),
    );
  }

  Future<void> _excluirInteressado() async {
    final interessadoId = _interessadoSelecionado!['id'] as int;
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Excluir interessado',
      mensagem: 'Tem certeza que deseja excluir este interessado? Esta ação não pode ser desfeita.',
      textoConfirmar: 'Excluir',
    );
    if (!confirmado) return;

    if (mounted) setState(() => _salvando = true);
    try {
      await ApiService.dio.delete('/interessados/$interessadoId');
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _interessadoSelecionado = null;
      });
      await _carregarInteressados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interessado excluído com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Erro ao excluir o interessado.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // No detalhe, "voltar" não fecha a tela: volta para a lista de interessados.
    return PopScope(
      canPop: _interessadoSelecionado == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _interessadoSelecionado = null);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Lista de Interessados')),
        floatingActionButton: _interessadoSelecionado == null
            ? FloatingActionButton(
                onPressed: () => _abrirModal(),
                tooltip: 'Adicionar interessado',
                child: const Icon(Icons.add),
              )
            : null,
        body: Stack(
          children: [
            _interessadoSelecionado != null
                ? DetalhesInteressado(
                    interessado: _interessadoSelecionado!,
                    salvando: _salvando,
                    onVoltar: () => setState(() => _interessadoSelecionado = null),
                    onEditar: () => _abrirModal(interessadoParaEditar: _interessadoSelecionado),
                    onExcluir: _excluirInteressado,
                    onTapCliente: () => _abrirDetalhesCliente(_interessadoSelecionado!),
                  )
                : _buildListagem(),
            if (_salvando) ...[
              const ModalBarrier(dismissible: false, color: Colors.black26),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListagem() {
    return Column(
      children: [
        PesquisaClienteLista(
          clienteSelecionado: _clienteFiltro,
          onSelecionado: _selecionarClienteFiltro,
          onLimpar: _limparFiltro,
          labelText: 'Pesquisar',
          hintText: 'Nome do cliente',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
              ? _buildErro()
              : ListaInteressados(
                  interessados: _interessados,
                  onSelecionarInteressado: (i) => setState(() => _interessadoSelecionado = i),
                ),
        ),
      ],
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: CoresSemanticas.erro, size: 40),
          const SizedBox(height: 8),
          Text(_erro!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _carregarInteressados,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
