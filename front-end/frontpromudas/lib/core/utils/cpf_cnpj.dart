import 'package:flutter/services.dart';

/// Remove tudo que não for dígito.
String limparCpfCnpj(String valor) => valor.replaceAll(RegExp(r'\D'), '');

bool _todosIguais(String v) => v.split('').every((c) => c == v[0]);

int _digitoVerificador(List<int> digitos, List<int> pesos) {
  var soma = 0;
  for (var i = 0; i < digitos.length; i++) {
    soma += digitos[i] * pesos[i];
  }
  final resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

bool _validarCpf(String cpf) {
  if (_todosIguais(cpf)) return false;
  final d = cpf.split('').map(int.parse).toList();
  final d1 = _digitoVerificador(d.sublist(0, 9), [10, 9, 8, 7, 6, 5, 4, 3, 2]);
  if (d1 != d[9]) return false;
  final d2 = _digitoVerificador(d.sublist(0, 10), [
    11,
    10,
    9,
    8,
    7,
    6,
    5,
    4,
    3,
    2,
  ]);
  return d2 == d[10];
}

bool _validarCnpj(String cnpj) {
  if (_todosIguais(cnpj)) return false;
  final d = cnpj.split('').map(int.parse).toList();
  final d1 = _digitoVerificador(d.sublist(0, 12), [
    5,
    4,
    3,
    2,
    9,
    8,
    7,
    6,
    5,
    4,
    3,
    2,
  ]);
  if (d1 != d[12]) return false;
  final d2 = _digitoVerificador(d.sublist(0, 13), [
    6,
    5,
    4,
    3,
    2,
    9,
    8,
    7,
    6,
    5,
    4,
    3,
    2,
  ]);
  return d2 == d[13];
}

/// Espera um valor já limpo (só dígitos). 11 dígitos → CPF; 14 → CNPJ.
bool validarCpfCnpj(String valorLimpo) {
  if (valorLimpo.length == 11) return _validarCpf(valorLimpo);
  if (valorLimpo.length == 14) return _validarCnpj(valorLimpo);
  return false;
}

/// Pronto para `TextFormField.validator`: campo é opcional (vazio é válido),
/// mas se preenchido precisa ter dígito verificador correto.
String? validarCampoCpfCnpj(String? valor) {
  final limpo = limparCpfCnpj(valor ?? '');
  if (limpo.isEmpty) return null;
  return validarCpfCnpj(limpo) ? null : 'CPF/CNPJ inválido.';
}

/// Formata um valor já limpo para exibição: CPF `000.000.000-00`,
/// CNPJ `00.000.000/0000-00`. Tamanho fora do padrão volta como recebido.
String formatarCpfCnpj(String valorLimpo) {
  if (valorLimpo.length == 11) {
    return '${valorLimpo.substring(0, 3)}.${valorLimpo.substring(3, 6)}.'
        '${valorLimpo.substring(6, 9)}-${valorLimpo.substring(9)}';
  }
  if (valorLimpo.length == 14) {
    return '${valorLimpo.substring(0, 2)}.${valorLimpo.substring(2, 5)}.'
        '${valorLimpo.substring(5, 8)}/${valorLimpo.substring(8, 12)}-'
        '${valorLimpo.substring(12)}';
  }
  return valorLimpo;
}

/// Máscara ao vivo para um único campo que aceita CPF ou CNPJ: aplica o
/// padrão de CPF enquanto houver até 11 dígitos digitados, e passa para o
/// padrão de CNPJ a partir do 12º dígito. Limita em 14 dígitos.
///
/// Simplificação aceita: o cursor sempre vai para o fim do texto formatado
/// a cada edição (não preserva posição relativa ao editar no meio do valor).
/// Correto para digitação sequencial, que é o uso normal deste campo.
class CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = limparCpfCnpj(newValue.text);
    final limitado = digitos.length > 14 ? digitos.substring(0, 14) : digitos;
    final texto = limitado.length <= 11
        ? _mascararCpf(limitado)
        : _mascararCnpj(limitado);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  String _mascararCpf(String d) {
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  String _mascararCnpj(String d) {
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5) buf.write('.');
      if (i == 8) buf.write('/');
      if (i == 12) buf.write('-');
      buf.write(d[i]);
    }
    return buf.toString();
  }
}
