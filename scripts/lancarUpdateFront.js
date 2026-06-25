// Lança uma atualização do app Flutter (auto-update via desktop_updater).
//
// Automatiza o "passo 2" do pipeline: sobe a versão no pubspec, empacota com o
// desktop_updater (que já faz o `flutter build windows`) e copia o pacote gerado
// para a pasta `updates/` servida pelo backend em /updates.
//
// Uso (na raiz do projeto):
//   npm run update-front            -> auto-incrementa patch e build
//   npm run update-front -- 0.3.0   -> usa a versão informada (build = atual + 1)
//
// Observações:
// - Só roda no Windows (o build do Flutter para desktop exige a máquina de dev).
// - A cópia vai para a pasta `updates/` LOCAL do projeto (o backend local enxerga
//   na hora). Em produção, essa pasta precisa ser enviada ao servidor.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const RAIZ = path.join(__dirname, '..');
const FRONT_DIR = path.join(RAIZ, 'front-end', 'frontpromudas');
const PUBSPEC = path.join(FRONT_DIR, 'pubspec.yaml');
const DIST_DIR = path.join(FRONT_DIR, 'dist', 'desktop_updater');
const UPDATES_DIR = path.join(RAIZ, 'updates');
const IP_SERVIDOR = '172.28.114.71:6072';

// Encerra com mensagem de erro e código 1.
function abortar(mensagem) {
  console.error(`\n❌ ${mensagem}`);
  process.exit(1);
}

// Calcula a versão nova a partir da atual e de um argumento opcional.
// Retorna { linha, versao } onde `linha` é o novo conteúdo de `version: ...`.
function calcularNovaVersao(conteudo, versaoArg) {
  const regex = /^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$/m;
  const match = conteudo.match(regex);
  if (!match) {
    abortar(
      'Não encontrei uma linha "version: X.Y.Z+B" no pubspec.yaml. ' +
        'Confira o formato antes de rodar de novo.',
    );
  }

  const [, maior, menor, patch, build] = match.map(Number);
  const novoBuild = build + 1;

  let novaVersaoSem; // "X.Y.Z" sem o build
  if (versaoArg) {
    if (!/^\d+\.\d+\.\d+$/.test(versaoArg)) {
      abortar(`Versão inválida: "${versaoArg}". Use o formato X.Y.Z (ex.: 0.3.0).`);
    }
    novaVersaoSem = versaoArg;
  } else {
    novaVersaoSem = `${maior}.${menor}.${patch + 1}`;
  }

  const versao = `${novaVersaoSem}+${novoBuild}`;
  return {
    conteudoNovo: conteudo.replace(regex, `version: ${versao}`),
    versao,
    versaoAntiga: `${maior}.${menor}.${patch}+${build}`,
  };
}

function main() {
  if (process.platform !== 'win32') {
    abortar(
      'Este script só roda no Windows (o build do Flutter desktop é feito na máquina de dev).',
    );
  }
  if (!fs.existsSync(PUBSPEC)) {
    abortar(`pubspec.yaml não encontrado em ${PUBSPEC}.`);
  }

  // 1 + 2. Bump da versão no pubspec.
  const versaoArg = process.argv[2];
  const conteudo = fs.readFileSync(PUBSPEC, 'utf8');
  const { conteudoNovo, versao, versaoAntiga } = calcularNovaVersao(conteudo, versaoArg);
  fs.writeFileSync(PUBSPEC, conteudoNovo);
  console.log(`\n🔖 Versão: ${versaoAntiga} -> ${versao}`);

  // 3. Empacota com o desktop_updater (faz o flutter build windows por dentro).
  console.log('\n📦 Gerando o pacote de atualização (flutter build + publish)...\n');
  // Comando estático passado como string única (com shell:true) — evita o aviso
  // DEP0190 do Node e resolve o `dart.bat` no Windows. Não há interpolação de
  // entrada do usuário aqui, então não há risco de injeção.
  const publish = spawnSync(
    'dart run desktop_updater:release publish --platform windows --mandatory',
    { cwd: FRONT_DIR, stdio: 'inherit', shell: true },
  );
  if (publish.status !== 0) {
    abortar(
      `O publish falhou (código ${publish.status}). A versão no pubspec já foi subida ` +
        `para ${versao}; corrija o erro e rode "npm run update-front" de novo.`,
    );
  }

  // 4. Copia o pacote gerado para a pasta updates/ (merge/overwrite).
  if (!fs.existsSync(DIST_DIR)) {
    abortar(`Pasta gerada não encontrada: ${DIST_DIR}. O publish não produziu o pacote.`);
  }
  fs.mkdirSync(UPDATES_DIR, { recursive: true });
  fs.cpSync(DIST_DIR, UPDATES_DIR, { recursive: true });

  // 5. Resumo.
  console.log('\n✅ Atualização pronta!');
  console.log(`   Versão publicada: ${versao}`);
  console.log(`   Pacote copiado para: ${UPDATES_DIR}`);
  console.log('\n📤 Em PRODUÇÃO: envie a pasta updates/ para o servidor ' +
    `(${IP_SERVIDOR}). Localmente, o backend já enxerga os arquivos na hora.`);
}

main();
