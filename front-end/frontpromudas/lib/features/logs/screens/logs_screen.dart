import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/services/log_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/api_feedback.dart';
import '../../../core/widgets/botao_data.dart';
import 'widgets/detalhes_atividade.dart';
import 'widgets/lista_atividades.dart';
import 'widgets/log_formatadores.dart';

/// Histórico de atividades do sistema (criação/alteração/exclusão de pedidos,
/// orçamentos, clientes etc.) — ver Parte 6 do plano de log/auditoria.
class TelaLogs extends StatefulWidget {
  const TelaLogs({super.key});

  @override
  State<TelaLogs> createState() => _TelaLogsState();
}

class _TelaLogsState extends State<TelaLogs> {
  final _service = LogService();

  List<Map<String, dynamic>> _atividades = [];
  int _total = 0;
  int _page = 1;
  bool _carregando = true;
  bool _carregandoMais = false;
  bool _exportando = false;
  String? _erro;

  DateTime? _de;
  DateTime? _ate;
  String? _entidadeFiltro;

  Map<String, dynamic>? _atividadeSelecionada;
  bool _carregandoDetalhe = false;
  bool _erroDetalhe = false;

  // Contadores de requisição: cada chamada assíncrona guarda o valor no
  // início e só aplica o resultado se ninguém disparou uma chamada mais
  // nova nesse meio-tempo — evita que uma resposta lenta (filtro trocado
  // rápido, ou duas seleções seguidas) sobrescreva um estado mais recente.
  int _listaRequestId = 0;
  int _selecaoRequestId = 0;

  static const _entidadesDisponiveis = [
    'pedido',
    'orcamento',
    'cliente',
    'produto',
    'pagamento',
    'entrega',
    'cheque',
    'forma_pagamento',
    'temporada',
  ];

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
      final resultado = await _service.listarAtividades(
        de: _de,
        ate: _ate,
        entidade: _entidadeFiltro,
        page: 1,
      );
      if (!mounted || meuRequestId != _listaRequestId) return;
      setState(() {
        _atividades = (resultado['dados'] as List)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _total = resultado['total'] as int? ?? _atividades.length;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || meuRequestId != _listaRequestId) return;
      setState(() {
        _erro = 'Não foi possível carregar o histórico.';
        _carregando = false;
      });
    }
  }

  Future<void> _carregarMais() async {
    final meuRequestId = _listaRequestId;
    setState(() => _carregandoMais = true);
    try {
      final proximaPagina = _page + 1;
      final resultado = await _service.listarAtividades(
        de: _de,
        ate: _ate,
        entidade: _entidadeFiltro,
        page: proximaPagina,
      );
      // Se um _carregar() novo rodou enquanto isso estava em voo (filtro
      // trocado, por exemplo), esta resposta é de uma listagem que não
      // existe mais — descarta em vez de misturar com o filtro atual.
      if (!mounted || meuRequestId != _listaRequestId) return;
      setState(() {
        _atividades.addAll((resultado['dados'] as List)
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

  // O resumo da listagem (GET /logs) não traz `snapshot_anterior`/`diferencas`
  // — só o detalhe (GET /logs/:id) calcula isso. Mostra o resumo na hora (pra
  // não parecer travado) e substitui pelo detalhe completo assim que chega.
  Future<void> _selecionarAtividade(Map<String, dynamic> resumo) async {
    final id = resumo['id'] as int?;
    final meuRequestId = ++_selecaoRequestId;
    setState(() {
      _atividadeSelecionada = resumo;
      _carregandoDetalhe = id != null;
      _erroDetalhe = false;
    });
    if (id == null) return;
    try {
      final detalhe = await _service.buscarAtividade(id);
      // Se o usuário já selecionou outro evento nesse meio-tempo, essa
      // resposta é da seleção anterior — descarta pra não sobrescrever a
      // seleção mais recente com dado desatualizado.
      if (!mounted || meuRequestId != _selecaoRequestId) return;
      setState(() {
        _atividadeSelecionada = detalhe;
        _carregandoDetalhe = false;
      });
    } catch (_) {
      if (!mounted || meuRequestId != _selecaoRequestId) return;
      // Antes ficava só com o resumo e o widget mostrava "sem evento
      // anterior" — enganoso quando o problema foi falha de rede, não a
      // ausência real de um evento anterior.
      setState(() {
        _carregandoDetalhe = false;
        _erroDetalhe = true;
      });
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

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      final bytes = await _service.exportarAtividadesCSV(
        entidade: _entidadeFiltro,
        de: _de,
        ate: _ate,
      );
      final caminho = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar histórico',
        fileName: 'historico.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (caminho == null) return;
      await File(caminho).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Histórico salvo em $caminho'),
            backgroundColor: CoresSemanticas.sucesso,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) mostrarErro(context, extrairErroApi(e, 'Não foi possível exportar o histórico.'));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _atividadeSelecionada == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _atividadeSelecionada = null);
      },
      child: Scaffold(
        appBar: _atividadeSelecionada != null
            ? null
            : AppBar(
                title: const Text('Histórico'),
                actions: [
                  _exportando
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.file_download_outlined),
                          tooltip: 'Exportar CSV',
                          onPressed: _atividades.isEmpty ? null : _exportar,
                        ),
                ],
              ),
        body: _atividadeSelecionada != null
            ? DetalhesAtividade(
                atividade: _atividadeSelecionada!,
                carregandoDiferencas: _carregandoDetalhe,
                erroDiferencas: _erroDetalhe,
                onVoltar: () => setState(() => _atividadeSelecionada = null),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Todas'),
                    selected: _entidadeFiltro == null,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _entidadeFiltro = null);
                      _carregar();
                    },
                  ),
                  for (final entidade in _entidadesDisponiveis)
                    FilterChip(
                      label: Text(rotuloEntidade(entidade)),
                      selected: _entidadeFiltro == entidade,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() =>
                            _entidadeFiltro = _entidadeFiltro == entidade ? null : entidade);
                        _carregar();
                      },
                    ),
                ],
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
                '$_total registro${_total == 1 ? '' : 's'}',
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
                  : ListaAtividades(
                      atividades: _atividades,
                      carregandoMais: _carregandoMais,
                      podeCarregarMais: _atividades.length < _total,
                      onCarregarMais: _carregarMais,
                      onSelecionar: _selecionarAtividade,
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
