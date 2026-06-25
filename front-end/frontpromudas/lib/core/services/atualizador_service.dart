import 'dart:io';

import 'package:desktop_updater/desktop_updater.dart';

import 'app_config.dart';

/// Configura o auto-update do app desktop (pacote `desktop_updater`).
///
/// O controller, ao ser criado, dispara automaticamente uma checagem de versão
/// contra o `app-archive.json` servido pelo backend (ver [AppConfig.updateArchiveUrl]).
/// Se a checagem falhar (servidor fora do ar, sem rede), o controller apenas
/// entra no estado `UpdateFailed` — o `UpdateDialogListener` **não** mostra nada
/// nesse caso, então o app abre normalmente (degradação graciosa).
///
/// Quando há versão nova publicada como **obrigatória** (`--mandatory`), o
/// diálogo é modal e sem botão de pular: o usuário precisa baixar e reiniciar
/// antes de usar o sistema.
class AtualizadorService {
  AtualizadorService._();

  /// Cria o controller já apontado para o servidor de atualizações, com os
  /// textos do diálogo em português. Retorna `null` em plataformas que não são
  /// desktop (onde o plugin não se aplica), para o app seguir sem auto-update.
  static DesktopUpdaterController? criarController() {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return null;
    }

    return DesktopUpdaterController(
      appArchiveUrl: AppConfig.updateArchiveUrl,
      localization: const DesktopUpdateLocalization(
        updateAvailableText: 'Atualização disponível',
        newVersionAvailableText: '{} {} está disponível',
        newVersionLongText:
            'Uma nova versão está pronta. Clique no botão abaixo para baixar '
            '(aprox. {} MB). O app será atualizado em seguida.',
        downloadText: 'Baixar',
        skipThisVersionText: 'Pular esta versão',
        restartText: 'Reiniciar para atualizar',
        warningTitleText: 'Confirmar atualização',
        restartWarningText:
            'É necessário reiniciar para concluir a atualização.\n'
            'Salve o que estiver fazendo antes de continuar.',
        warningCancelText: 'Agora não',
        warningConfirmText: 'Reiniciar',
        saveFirstText: 'Salvar primeiro',
        downloadLatestText: 'Baixar a versão mais recente',
        freshInstallRequiredText:
            'Esta versão não consegue instalar a atualização com segurança. '
            'Baixe a versão mais recente.',
        supportPolicyBlockedText:
            'Esta versão não é mais suportada. Atualize para continuar.',
        upToDateTitleText: 'O aplicativo está atualizado',
        upToDateText: '{} é a versão mais recente.',
        updateCheckFailedTitleText: 'Não foi possível verificar atualizações',
        updateCheckFailedText: 'Tente novamente mais tarde.',
        okText: 'OK',
      ),
    );
  }
}
