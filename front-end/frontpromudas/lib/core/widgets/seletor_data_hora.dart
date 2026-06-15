import 'package:flutter/material.dart';

/// Abre um seletor de data seguido de um seletor de hora e retorna o
/// `DateTime` combinado (local), ou `null` se o usuário cancelar qualquer etapa.
/// Reutilizável em qualquer tela que precise editar data + hora.
Future<DateTime?> selecionarDataHora(
  BuildContext context,
  DateTime inicial,
) async {
  final data = await showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (data == null || !context.mounted) return null;

  final hora = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(inicial),
  );
  if (hora == null) return null;

  return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
}

/// Formata um `DateTime` (ou ISO string) como `dd/MM/yyyy HH:mm` no fuso local.
/// Retorna '—' quando o valor é nulo/ inválido.
String formatarDataHora(dynamic valor) {
  if (valor == null) return '—';
  final dt = valor is DateTime
      ? valor
      : DateTime.tryParse(valor.toString())?.toLocal();
  if (dt == null) return '—';
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
