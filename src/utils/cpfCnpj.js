// Limpeza, validação (dígito verificador) e formatação de CPF/CNPJ.
// Armazenamento no banco é sempre só dígitos — máscara é responsabilidade do
// frontend (e do PDF, na hora de exibir).

function limpar(valor) {
  return String(valor ?? '').replace(/\D/g, '');
}

function todosIguais(v) {
  return v.split('').every((c) => c === v[0]);
}

function digitoVerificador(digitos, pesos) {
  const soma = digitos.reduce((acc, d, i) => acc + d * pesos[i], 0);
  const resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

function validarCpf(cpf) {
  if (todosIguais(cpf)) return false;
  const d = cpf.split('').map(Number);
  const d1 = digitoVerificador(d.slice(0, 9), [10, 9, 8, 7, 6, 5, 4, 3, 2]);
  if (d1 !== d[9]) return false;
  const d2 = digitoVerificador(d.slice(0, 10), [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]);
  return d2 === d[10];
}

function validarCnpj(cnpj) {
  if (todosIguais(cnpj)) return false;
  const d = cnpj.split('').map(Number);
  const d1 = digitoVerificador(d.slice(0, 12), [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
  if (d1 !== d[12]) return false;
  const d2 = digitoVerificador(d.slice(0, 13), [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
  return d2 === d[13];
}

// Espera um valor já limpo (só dígitos). Dispara pelo tamanho: 11 = CPF, 14 = CNPJ.
function validar(valorLimpo) {
  if (valorLimpo.length === 11) return validarCpf(valorLimpo);
  if (valorLimpo.length === 14) return validarCnpj(valorLimpo);
  return false;
}

// Formata um valor já limpo para exibição (PDF). Tamanho fora do padrão é
// devolvido como está (defensivo — não deveria ocorrer após a validação).
function formatar(valorLimpo) {
  if (!valorLimpo) return valorLimpo;
  if (valorLimpo.length === 11) {
    return valorLimpo.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4');
  }
  if (valorLimpo.length === 14) {
    return valorLimpo.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
  }
  return valorLimpo;
}

module.exports = { limpar, validar, formatar };
