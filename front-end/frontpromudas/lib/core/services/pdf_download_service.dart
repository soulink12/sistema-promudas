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
  static Future<void> baixarESalvar(BuildContext context, int pedidoId) async {
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

    try {
      final response = await ApiService.dio.get(
        '/pedidos/$pedidoId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);

      final nomeArquivo = _nomeArquivo(
        response.headers.value('content-disposition'),
        pedidoId,
      );

      // Dentro da pasta do usuário, organiza por temporada: subpasta "26" para
      // pedidos da safra 2026 (ex.: "Pedido 26-1.pdf"). Cria a subpasta se ainda
      // não existir. Pedidos sem temporada vão direto na pasta raiz.
      final subpasta = _pastaTemporada(nomeArquivo);
      final destino = subpasta == null
          ? pasta
          : '$pasta${Platform.pathSeparator}$subpasta';
      await Directory(destino).create(recursive: true);

      final caminho = '$destino${Platform.pathSeparator}$nomeArquivo';
      await File(caminho).writeAsBytes(bytes);

      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(bytes: bytes, nomeArquivo: nomeArquivo, pedidoId: pedidoId),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        _avisar(
          context,
          'Não foi possível gerar o PDF do pedido.',
          CoresSemanticas.erro,
        );
      }
    }
  }

  /// Extrai o nome do arquivo do cabeçalho `Content-Disposition`
  /// (`attachment; filename="Pedido 26-1.pdf"`), com fallback seguro.
  static String _nomeArquivo(String? contentDisposition, int pedidoId) {
    String nome = 'pedido_$pedidoId.pdf';
    if (contentDisposition != null) {
      final match =
          RegExp(r'filename="?([^"]+)"?').firstMatch(contentDisposition);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        nome = match.group(1)!.trim();
      }
    }
    // Remove caracteres inválidos para nome de arquivo no Windows.
    return nome.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  }

  /// Deriva a subpasta da temporada a partir do nome ("Pedido 26-1.pdf" → "26").
  /// Retorna `null` quando o pedido não tem temporada (nome "Pedido #5.pdf").
  static String? _pastaTemporada(String nomeArquivo) {
    final match = RegExp(r'Pedido\s+(\d+)-').firstMatch(nomeArquivo);
    return match?.group(1);
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
