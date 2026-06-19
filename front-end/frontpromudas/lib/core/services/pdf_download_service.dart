import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../theme/cores_semanticas.dart';

class PdfDownloadService {
  static Future<void> baixarESalvar(BuildContext context, int pedidoId) async {
    try {
      final response = await ApiService.dio.get(
        '/pedidos/$pedidoId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);

      final caminho = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar recibo do pedido',
        fileName: 'pedido_$pedidoId.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (caminho == null) return;

      await File(caminho).writeAsBytes(bytes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível gerar o PDF do pedido.'),
            backgroundColor: CoresSemanticas.erro,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
