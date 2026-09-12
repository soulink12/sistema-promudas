import 'package:flutter/material.dart';
import '../../../core/services/log_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/widgets/botao_data.dart';
import 'widgets/detalhes_erro.dart';
import 'widgets/lista_erros.dart';

/// Log de erros reais/inesperados do sistema (500, exceptions não tratadas,
/// crash) — não inclui validações de negócio. Ver Parte 6 do plano de
/// log/auditoria.
class TelaLogsErros extends StatefulWidget {
  const TelaLogsErros({super.key});

  @override
  State<TelaLogsErros> createState() => _TelaLogsErrosState();
}

class _TelaLogsErrosState extends State<TelaLogsErros> {
  final _service = LogService();

  List<Map<String, dynamic>> _erros = [];
  int _total = 0;
  int _page = 1;
  bool _carregando = true;
  bool _carregandoMais = false;
  String? _erro;

  DateTime? _de;
  DateTime? _ate;

  Map<String, dynamic>? _erroSelecionado;

  // Guarda contra resposta fora de ordem — mesma razão de logs_screen.dart:
  // uma troca rápida de filtro não pode deixar uma resposta antiga
  // sobrescrever o estado da listagem atual.
  int _listaRequestId = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final meuRequestId = ++_listaRequestId;
    setState(() {
      _carregando = true;
      _erro = null;
      _page = 1;
    });
    try {
      final resultado = await _service.listarErros(de: _de, ate: _ate, page: 1);
      if (!mounted || meuRequestId != _listaRequestId) return;
      setState(() {
        _erros = (resultado['dados'] as List)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _total = resultado['total'] as int? ?? _erros.length;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || meuRequestId != _listaRequestId) return;
      setState(() {
        _erro = 'Não foi possível carregar o log de erros.';
        _carregando = false;
      });
    }
  }

  Future<void> _carregarMais() async {
    final meuRequestId = _listaRequestId;
    setState(() => _carregandoMais = true);
    try {
      final proximaPagina = _page + 1;
      final resultado =
          await _service.listarErros(de: _de, ate: _ate, page: proximaPagina);
      if (!mounted || meuRequestId != _listaRequestId) return;
      setState(() {
        _erros.addAll((resultado['dados'] as List)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)));
        _page = proximaPagina;
        _carregandoMais = false;
      });
    } catch (_) {
      if (mounted && meuRequestId == _listaRequestId) {
        setState(() => _carregandoMais = false);
      }
    }
  }

  Future<void> _selecionarData(bool isDe) async {
    final inicial = isDe ? (_de ?? DateTime.now()) : (_ate ?? DateTime.now());
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;
    setState(() {
      if (isDe) {
        _de = data;
      } else {
        _ate = DateTime(data.year, data.month, data.day, 23, 59, 59);
      }
    });
    _carregar();
  }

  String _formatarData(DateTime? dt) {
    if (dt == null) return 'Selecionar';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _erroSelecionado == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _erroSelecionado = null);
      },
      child: Scaffold(
        appBar: _erroSelecionado != null
            ? null
            : AppBar(title: const Text('Log de Erros')),
        body: _erroSelecionado != null
            ? DetalhesErro(
                erro: _erroSelecionado!,
                onVoltar: () => setState(() => _erroSelecionado = null),
              )
            : _buildListagem(),
      ),
    );
  }

  Widget _buildListagem() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: BotaoData(
                  label: 'De',
                  valor: _formatarData(_de),
                  selecionado: _de != null,
                  onTap: () => _selecionarData(true),
                  onLimpar: _de != null
                      ? () {
                          setState(() => _de = null);
                          _carregar();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BotaoData(
                  label: 'Até',
                  valor: _formatarData(_ate),
                  selecionado: _ate != null,
                  onTap: () => _selecionarData(false),
                  onLimpar: _ate != null
                      ? () {
                          setState(() => _ate = null);
                          _carregar();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (_total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$_total erro${_total == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro != null
                  ? _buildErro()
                  : ListaErros(
                      erros: _erros,
                      carregandoMais: _carregandoMais,
                      podeCarregarMais: _erros.length < _total,
                      onCarregarMais: _carregarMais,
                      onSelecionar: (e) => setState(() => _erroSelecionado = e),
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
          FilledButton(onPressed: _carregar, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
