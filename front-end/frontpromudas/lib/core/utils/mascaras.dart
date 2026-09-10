import 'package:flutter/services.dart';

/// Máscaras "ao vivo" dos campos de cadastro, no mesmo formato do
/// `CpfCnpjInputFormatter` (ver core/utils/cpf_cnpj.dart).
///
/// Simplificação aceita, igual à do CPF/CNPJ: o cursor vai para o fim do texto
/// a cada edição, em vez de preservar a posição relativa. Correto para
/// digitação sequencial, que é o uso normal desses campos.

String _somenteDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

/// Telefone brasileiro: `(63) 3333-3333` com 10 dígitos e
/// `(63) 99999-9999` com 11. Limita em 11 dígitos.
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = _somenteDigitos(newValue.text);
    final limitado = digitos.length > 11 ? digitos.substring(0, 11) : digitos;

    final buf = StringBuffer();
    for (var i = 0; i < limitado.length; i++) {
      if (i == 0) buf.write('(');
      if (i == 2) buf.write(') ');
      // Celular (11 dígitos) separa depois do 5º; fixo (10), depois do 4º.
      if (limitado.length == 11 ? i == 7 : i == 6) buf.write('-');
      buf.write(limitado[i]);
    }

    final texto = buf.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// CEP: `77400-000`. Limita em 8 dígitos.
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = _somenteDigitos(newValue.text);
    final limitado = digitos.length > 8 ? digitos.substring(0, 8) : digitos;

    final buf = StringBuffer();
    for (var i = 0; i < limitado.length; i++) {
      if (i == 5) buf.write('-');
      buf.write(limitado[i]);
    }

    final texto = buf.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
