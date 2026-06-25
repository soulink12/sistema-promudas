import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/botao_data.dart';
import '../../../core/widgets/campo_busca_cliente.dart';
import '../../../core/widgets/chip_status.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/formatadores.dart';

class TelaRelatorioPedidos extends StatefulWidget {
  const TelaRelatorioPedidos({super.key});

  @override
  State<TelaRelatorioPedidos> createState() => _TelaRelatorioPedidosState();
}

class _TelaRelatorioPedidosState extends State<TelaRelatorioPedidos> {
  DateTime? _de;
  DateTime? _ate;
  String? _statusPagamento;
  String? _statusEntrega;
  Map<String, dynamic>? _clienteSelecionado;

  Map<String, dynamic>? _resultado;
  bool _carregando = false;
  bool _baixandoPdf = false;

  Future<void> _gerarRelatorio() async {
    setState(() {
      _carregando = true;
      _resultado = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_de != null) params['de'] = _de!.toIso8601String();
      if (_ate != null) {
        final fim = DateTime(_ate!.year, _ate!.month, _ate!.day, 23, 59, 59);
        params['ate'] = fim.toIso8601String();
      }
      if (_statusPagamento != null) params['statusPagamento'] = _statusPagamento;
      if (_statusEntrega != null) params['statusEntrega'] = _statusEntrega;
      if (_clienteSelecionado != null) {
        params['clienteId'] = _clienteSelecionado!['id'];
      }

      final response = await ApiService.dio.get(
        '/relatorios/pedidos',
        queryParameters: params,
      );

      setState(() {
        _resultado = Map<String, dynamic>.from(response.data as Map);
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar relatório. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    }
  }

  Future<void> _baixarPdf() async {
    setState(() => _baixandoPdf = true);
    try {
      final params = <String, dynamic>{};
      if (_de != null) params['de'] = _de!.toIso8601String();
      if (_ate != null) {
        final fim = DateTime(_ate!.year, _ate!.month, _ate!.day, 23, 59, 59);
        params['ate'] = fim.toIso8601String();
      }
      if (_statusPagamento != null) params['statusPagamento'] = _statusPagamento;
      if (_statusEntrega != null) params['statusEntrega'] = _statusEntrega;
      if (_clienteSelecionado != null) params['clienteId'] = _clienteSelecionado!['id'];

      final response = await ApiService.dio.get(
        '/relatorios/pedidos/pdf',
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);

      final caminho = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar relatório de pedidos',
        fileName: 'relatorio_pedidos.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (caminho == null) return;
      await File(caminho).writeAsBytes(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível gerar o PDF do relatório.'),
            backgroundColor: CoresSemanticas.erro,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _baixandoPdf = false);
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
        if (_ate != null && _ate!.isBefore(_de!)) _ate = null;
      } else {
        _ate = data;
        if (_de != null && _de!.isAfter(_ate!)) _de = null;
      }
    });
  }

  String _formatarData(DateTime? dt) {
    if (dt == null) return 'Selecionar';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resultado?['resumo'] as Map<String, dynamic>?;
    final lista = (_resultado?['lista'] as List?)
        ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de Pedidos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Filtros ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FILTROS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: BotaoData(
                          label: 'De',
                          valor: _formatarData(_de),
                          selecionado: _de != null,
                          onTap: () => _selecionarData(true),
                          onLimpar: _de != null
                              ? () => setState(() => _de = null)
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
                              ? () => setState(() => _ate = null)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FiltroStatus(
                    label: 'STATUS DE PAGAMENTO',
                    opcoes: const ['Pago', 'Crédito', 'Parcial', 'Pendente'],
                    selecionado: _statusPagamento,
                    onSelecionar: (v) => setState(() => _statusPagamento = v),
                  ),
                  const SizedBox(height: 12),
                  _FiltroStatus(
                    label: 'STATUS DE ENTREGA',
                    opcoes: const ['Entregue', 'Parcial', 'Pendente'],
                    selecionado: _statusEntrega,
                    onSelecionar: (v) => setState(() => _statusEntrega = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CLIENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_clienteSelecionado == null)
                    CampoBuscaCliente(
                      labelText: 'Cliente (opcional)',
                      hintText: 'Buscar por nome, CPF ou telefone',
                      onSelecionado: (c) =>
                          setState(() => _clienteSelecionado = c),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _clienteSelecionado!['nome'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          tooltip: 'Remover filtro de cliente',
                          onPressed: () =>
                              setState(() => _clienteSelecionado = null),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _carregando ? null : _gerarRelatorio,
                      icon: _carregando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Gerar Relatório'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Resultados ───────────────────────────────────────────────
          if (resumo != null && lista != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _CardResumo(
                  valor: '${resumo['total']}',
                  label: 'pedidos',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardResumo(
                    valor: formatarMoeda(resumo['valorTotal'] as num),
                    label: 'valor total',
                  ),
                ),
                const SizedBox(width: 8),
                _baixandoPdf
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton.filled(
                        onPressed: _baixarPdf,
                        tooltip: 'Exportar PDF',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        icon: const Icon(Icons.picture_as_pdf),
                      ),
              ],
            ),
            if ((resumo['porStatusPagamento'] as Map?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry
                      in (resumo['porStatusPagamento'] as Map).entries)
                    if ((entry.value as int) > 0)
                      ChipStatus(
                          status: entry.key as String,
                          count: entry.value as int),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhum pedido encontrado para os filtros selecionados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              for (final p in lista) ...[
                _CardPedido(pedido: p),
                const SizedBox(height: 8),
              ],
          ],
        ],
      ),
    );
  }
}

// ── Filtro de status com chips ─────────────────────────────────────────────

class _FiltroStatus extends StatelessWidget {
  final String label;
  final List<String> opcoes;
  final String? selecionado;
  final void Function(String?) onSelecionar;

  const _FiltroStatus({
    required this.label,
    required this.opcoes,
    required this.selecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Todos'),
              selected: selecionado == null,
              onSelected: (_) => onSelecionar(null),
              showCheckmark: false,
            ),
            for (final opcao in opcoes)
              FilterChip(
                label: Text(opcao),
                selected: selecionado == opcao,
                onSelected: (_) =>
                    onSelecionar(selecionado == opcao ? null : opcao),
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }
}

// ── Cards de resumo ────────────────────────────────────────────────────────

class _CardResumo extends StatelessWidget {
  final String valor;
  final String label;

  const _CardResumo({required this.valor, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: TextStyle(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                  color: cs.onPrimary.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de pedido individual ──────────────────────────────────────────────

class _CardPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;

  const _CardPedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final numero = formatarNumeroPedido(pedido);
    final cliente = pedido['cliente'] as String? ?? '—';
    final valor = formatarMoeda(pedido['valor_total'] as num);
    final qtdItens = pedido['qtd_itens'] as int? ?? 0;
    final statusPag = pedido['status_pagamento'] as String? ?? '—';
    final statusRet = pedido['status_entrega'] as String? ?? '—';
    final data = formatarDataHora(pedido['criado_em']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cliente,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$numero · $data',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                Text(
                  '$qtdItens ${qtdItens == 1 ? 'item' : 'itens'}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChipStatus(status: statusPag),
                const SizedBox(width: 8),
                ChipStatus(status: statusRet),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

