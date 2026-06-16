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
