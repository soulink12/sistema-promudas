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

module.exports = { formatarMoeda };
