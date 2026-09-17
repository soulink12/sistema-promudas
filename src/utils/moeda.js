// Formatação monetária no padrão brasileiro (R$ 1.234,56) para os PDFs.
// Implementação manual (sem toLocaleString) porque o Node do servidor Ubuntu
// usa small-icu, que só conhece o locale inglês — mesma razão das datas.

function formatarMoeda(valor) {
  const numero = parseFloat(valor || 0);
  const negativo = numero < 0;
  const [inteiro, centavos] = Math.abs(numero).toFixed(2).split('.');

  // Insere o ponto de milhar a cada 3 dígitos, da direita para a esquerda.
  const inteiroFormatado = inteiro.replace(/\B(?=(\d{3})+(?!\d))/g, '.');

  return `R$ ${negativo ? '-' : ''}${inteiroFormatado},${centavos}`;
}

// Formata um inteiro com ponto de milhar (1234 -> "1.234"), sem casas decimais.
// Mesma técnica de formatarMoeda (sem toLocaleString, por causa do small-icu).
function formatarInteiro(valor) {
  const numero = Math.trunc(Math.abs(Number(valor) || 0));
  const sinal = Number(valor) < 0 ? '-' : '';
  return `${sinal}${String(numero).replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
}

module.exports = { formatarMoeda, formatarInteiro };
