import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../theme/cores_semanticas.dart';

/// Tela cheia com o preview de um PDF já em memória. Usada depois de
/// baixar/salvar o PDF de um pedido — evita abrir o visualizador externo do
/// Windows, que quebraria o modo quiosque (app sem borda, tela cheia) do
/// aplicativo.
///
/// Layout próprio (em vez do [PdfPreview] padrão): botões no topo (na
/// AppBar), página sempre começa centralizada cabendo inteira na tela, e
/// zoom/scroll são tratados manualmente (ver [_aoRolarMouse]) — o
/// [InteractiveViewer] do pacote faz roda-do-mouse = zoom por padrão, sem
/// suporte a Ctrl, então não dá pra usar o gesto embutido dele aqui.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.nomeArquivo,
    required this.pedidoId,
  });

  final Uint8List bytes;
  final String nomeArquivo;

  /// Usado para buscar sob demanda a versão de 3 vias do PDF (ver
  /// [_imprimir3Vias]) — o arquivo salvo em disco continua vindo só de
  /// [bytes], com 1 via.
  final int pedidoId;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  static const _zoomMinimo = 0.5;
  static const _zoomMaximo = 3.0;
  static const _zoomPassoBotao = 0.25;
  // Sensibilidade do Ctrl+scroll (scrollDelta.dy costuma vir em dezenas por "clique" da roda).
  static const _zoomPassoScroll = 0.001;

  double _zoom = 1.0;
  Offset _pan = Offset.zero;

  // Cache da versão de 3 vias (buscada sob demanda no backend, só quando o
  // usuário clica em "Imprimir 3 vias" pela primeira vez).
  Uint8List? _bytes3Vias;
  bool _carregando3Vias = false;

  // Preenchidos a cada build de _paginaAjustada, usados para limitar o pan
  // às bordas da página (ver _limitarPan).
  Size? _tamanhoViewport;
  double? _larguraBase;
  double? _alturaBase;

  void _definirZoom(double novoZoom) {
    setState(() {
      _zoom = novoZoom.clamp(_zoomMinimo, _zoomMaximo);
      _pan = Offset.zero; // todo zoom recentraliza a página
    });
  }

  void _zoomMais() => _definirZoom(_zoom + _zoomPassoBotao);
  void _zoomMenos() => _definirZoom(_zoom - _zoomPassoBotao);

  /// Ctrl+roda = zoom (centralizado); roda sozinha = scroll da página, só
  /// quando ela já está com zoom (abaixo de 100% ela cabe inteira na tela).
  void _aoRolarMouse(PointerSignalEvent evento) {
    if (evento is! PointerScrollEvent) return;
    if (HardwareKeyboard.instance.isControlPressed) {
      _definirZoom(_zoom - evento.scrollDelta.dy * _zoomPassoScroll * _zoom);
    } else if (_zoom > 1.0) {
      setState(() => _pan = _limitarPan(_pan - evento.scrollDelta));
    }
  }

  /// Trava o pan nas bordas da página: nunca deixa aparecer vazio além do
  /// topo/base (nem das laterais) — se a página cabe inteira num eixo
  /// (zoom baixo), esse eixo fica travado em 0 (sempre centralizado).
  Offset _limitarPan(Offset pan) {
    final viewport = _tamanhoViewport;
    final larguraBase = _larguraBase;
    final alturaBase = _alturaBase;
    if (viewport == null || larguraBase == null || alturaBase == null) {
      return pan;
    }

    final panXMaximo = math.max(0.0, (larguraBase * _zoom - viewport.width) / 2);
    final panYMaximo = math.max(0.0, (alturaBase * _zoom - viewport.height) / 2);

    return Offset(
      pan.dx.clamp(-panXMaximo, panXMaximo),
      pan.dy.clamp(-panYMaximo, panYMaximo),
    );
  }

  Future<void> _imprimir() {
    return Printing.layoutPdf(onLayout: (_) async => widget.bytes, name: widget.nomeArquivo);
  }

  /// Imprime 3 vias do pedido de uma vez, num único PDF (mesmo diálogo de
  /// impressão, 3 cópias). Busca a versão de 3 vias no backend na primeira
  /// vez e reaproveita o resultado nos cliques seguintes — não mexe no
  /// arquivo já salvo em disco, que continua com 1 via.
  Future<void> _imprimir3Vias() async {
    if (_bytes3Vias != null) {
      await Printing.layoutPdf(onLayout: (_) async => _bytes3Vias!, name: widget.nomeArquivo);
      return;
    }

    setState(() => _carregando3Vias = true);
    try {
      final response = await ApiService.dio.get(
        '/pedidos/${widget.pedidoId}/pdf',
        queryParameters: {'copias': 3},
        options: Options(responseType: ResponseType.bytes),
      );
      _bytes3Vias = Uint8List.fromList(response.data as List<int>);
      await Printing.layoutPdf(onLayout: (_) async => _bytes3Vias!, name: widget.nomeArquivo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível gerar as 3 vias do pedido.'),
            backgroundColor: CoresSemanticas.erro,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando3Vias = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _imprimir,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.nomeArquivo),
            actions: [
              IconButton(
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Diminuir zoom',
                onPressed: _zoomMenos,
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Aumentar zoom',
                onPressed: _zoomMais,
              ),
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Imprimir (Ctrl+P)',
                onPressed: _imprimir,
              ),
              IconButton(
                icon: _carregando3Vias
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.filter_3),
                tooltip: 'Imprimir 3 vias',
                onPressed: _carregando3Vias ? null : _imprimir3Vias,
              ),
            ],
          ),
          body: Listener(
            onPointerSignal: _aoRolarMouse,
            child: Container(
              color: Colors.grey.shade300,
              child: PdfPreview.builder(
                build: (format) async => widget.bytes,
                pdfFileName: widget.nomeArquivo,
                useActions: false,
                canDebug: false,
                pagesBuilder: (context, pages) => PageView.builder(
                  itemCount: pages.length,
                  itemBuilder: (context, index) => _paginaAjustada(pages[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tamanho-base da página (cabendo inteira, centralizada) mais a
  /// transformação de zoom/pan atual, aplicada em torno do centro da tela.
  Widget _paginaAjustada(PdfPreviewPageData pagina) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final escalaBase = math.min(
            constraints.maxWidth / pagina.width,
            constraints.maxHeight / pagina.height,
          );
          final larguraBase = pagina.width * escalaBase;
          final alturaBase = pagina.height * escalaBase;
          final centroX = constraints.maxWidth / 2;
          final centroY = constraints.maxHeight / 2;

          _tamanhoViewport = Size(constraints.maxWidth, constraints.maxHeight);
          _larguraBase = larguraBase;
          _alturaBase = alturaBase;

          final matriz = Matrix4.identity()
            ..translateByDouble(centroX + _pan.dx, centroY + _pan.dy, 0, 1)
            ..scaleByDouble(_zoom, _zoom, 1, 1)
            ..translateByDouble(-centroX, -centroY, 0, 1);

          return ClipRect(
            child: Transform(
              transform: matriz,
              child: Center(
                child: Container(
                  width: larguraBase,
                  height: alturaBase,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(offset: Offset(0, 3), blurRadius: 6, color: Colors.black38)],
                  ),
                  child: Image(image: pagina.image, fit: BoxFit.fill),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
