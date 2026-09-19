import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'pdf_config_service.dart';
import '../theme/cores_semanticas.dart';
import '../widgets/pdf_preview_screen.dart';

class PdfDownloadService {
  /// Baixa o PDF do pedido, salva na pasta configurada em Configurações e abre
  /// o preview embutido do app (com opção de impressão). O nome do arquivo
  /// ("Pedido AA-N.pdf") vem do backend, no cabeçalho `Content-Disposition`.
  ///
  /// [clienteEmail] habilita o botão de "Enviar por e-mail" no preview quando
  /// o cliente do pedido tem e-mail cadastrado.
  static Future<void> baixarESalvar(
    BuildContext context,
    int pedidoId, {
    String? clienteEmail,
  }) async {
    await _baixarESalvar(
      context,
      id: pedidoId,
      caminhoBase: '/pedidos',
      mostrarImprimir3Vias: true,
      clienteEmail: clienteEmail,
    );
  }

  /// Mesma lógica de [baixarESalvar], mas para o PDF de um orçamento
  /// ("Orçamento OAA-N.pdf") — sem a opção de imprimir 3 vias.
  static Future<void> baixarESalvarOrcamento(
    BuildContext context,
    int orcamentoId, {
    String? clienteEmail,
  }) async {
    await _baixarESalvar(
      context,
      id: orcamentoId,
      caminhoBase: '/orcamentos',
      mostrarImprimir3Vias: false,
      clienteEmail: clienteEmail,
    );
  }

  static Future<void> _baixarESalvar(
    BuildContext context, {
    required int id,
    required String caminhoBase,
    required bool mostrarImprimir3Vias,
    String? clienteEmail,
  }) async {
    // Sem pasta configurada não há onde salvar — orienta o usuário e sai.
    final pasta = PdfConfigService.pasta.value;
    if (pasta == null) {
      _avisar(
        context,
        'Defina a pasta para salvar os PDFs em Configurações do Aplicativo.',
        CoresSemanticas.erro,
      );
      return;
    }

    Uint8List bytes;
    String nomeArquivo;
    try {
      final response = await ApiService.dio.get(
        '$caminhoBase/$id/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      bytes = Uint8List.fromList(response.data as List<int>);

      nomeArquivo = _nomeArquivo(
        response.headers.value('content-disposition'),
        id,
      );
    } catch (_) {
      if (context.mounted) {
        _avisar(
          context,
          'Não foi possível gerar o PDF.',
          CoresSemanticas.erro,
        );
      }
      return;
    }

    try {
      // Dentro da pasta do usuário, organiza por temporada: subpasta "26" para
      // pedidos da safra 2026 (ex.: "Pedido 26-1.pdf"), e "26/Orçamentos"
      // para orçamentos da mesma safra (ex.: "Orçamento O26-3.pdf"). Cria a(s)
      // subpasta(s) se ainda não existir(em). Sem temporada, vai direto na raiz.
      final subpasta = _pastaTemporada(nomeArquivo);
      final destino = subpasta == null
          ? pasta
          : '$pasta${Platform.pathSeparator}$subpasta';
      await Directory(destino).create(recursive: true);

      final caminho = '$destino${Platform.pathSeparator}$nomeArquivo';
      await File(caminho).writeAsBytes(bytes);
    } catch (_) {
      if (context.mounted) {
        _avisar(
          context,
          'PDF gerado, mas não foi possível salvar na pasta configurada. Verifique o caminho em Configurações.',
          CoresSemanticas.erro,
        );
      }
      return;
    }

    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            bytes: bytes,
            nomeArquivo: nomeArquivo,
            pedidoId: id,
            mostrarImprimir3Vias: mostrarImprimir3Vias,
            caminhoEnviarEmail: '$caminhoBase/$id/enviar-email',
            clienteEmail: clienteEmail,
          ),
        ),
      );
    }
  }

  /// Extrai o nome do arquivo do cabeçalho `Content-Disposition`
  /// (`attachment; filename="Pedido 26-1.pdf"; filename*=UTF-8''Pedido%20...`),
  /// com fallback seguro. Prioriza o parâmetro `filename*` (RFC 5987,
  /// percent-encoded UTF-8) sobre o `filename=` puro ASCII, que o backend
  /// manda sem acentos porque cabeçalhos HTTP não suportam UTF-8 direto.
  static String _nomeArquivo(String? contentDisposition, int pedidoId) {
    String nome = 'pedido_$pedidoId.pdf';
    if (contentDisposition != null) {
      final matchExtended =
          RegExp(r"filename\*=UTF-8''([^;]+)").firstMatch(contentDisposition);
      if (matchExtended != null && matchExtended.group(1)!.trim().isNotEmpty) {
        nome = Uri.decodeComponent(matchExtended.group(1)!.trim());
      } else {
        final match =
            RegExp(r'filename="?([^"]+)"?').firstMatch(contentDisposition);
        if (match != null && match.group(1)!.trim().isNotEmpty) {
          nome = match.group(1)!.trim();
        }
      }
    }
    // Remove caracteres inválidos para nome de arquivo no Windows.
    return nome.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  }

  /// Deriva a subpasta da temporada a partir do nome: pedido vai direto na
  /// pasta da safra ("Pedido 26-1.pdf" → "26"), orçamento numerado ganha uma
  /// subpasta própria dentro dela ("Orçamento O26-3.pdf" → "26/Orçamentos").
  /// Retorna `null` quando não tem temporada (nome com "#id", ex. "Pedido
  /// #5.pdf" ou "Orçamento #5.pdf") — cai na raiz da pasta configurada.
  static String? _pastaTemporada(String nomeArquivo) {
    final matchOrcamento = RegExp(r'Orçamento\s+O(\d+)-').firstMatch(nomeArquivo);
    if (matchOrcamento != null) {
      return '${matchOrcamento.group(1)}${Platform.pathSeparator}Orçamentos';
    }
    final matchPedido = RegExp(r'Pedido\s+(\d+)-').firstMatch(nomeArquivo);
    return matchPedido?.group(1);
  }

  static void _avisar(BuildContext context, String texto, Color cor) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: cor,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
