import 'package:flutter/material.dart';
import '../../../core/services/theme_service.dart';

/// Configurações do Aplicativo — preferências de aparência (tema + tamanho da
/// fonte). Transversal: acessível em todos os módulos (PDV, Entregas, Admin).
/// Os cadastros do sistema (produtos/formas) ficam em [TelaConfiguracoesSistema],
/// exclusiva da Administração.
class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações do Aplicativo')),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeMode,
            builder: (context, mode, _) {
              return SwitchListTile(
                secondary: Icon(
                  mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Tema escuro'),
                subtitle: Text(
                  mode == ThemeMode.dark ? 'Ativado' : 'Desativado',
                ),
                value: mode == ThemeMode.dark,
                onChanged: (_) => ThemeService.toggleTheme(),
              );
            },
          ),
          ValueListenableBuilder<TamanhoFonte>(
            valueListenable: ThemeService.tamanhoFonte,
            builder: (context, tamanho, _) {
              return ListTile(
                leading: const Icon(Icons.format_size),
                title: const Text('Tamanho da fonte'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SegmentedButton<TamanhoFonte>(
                    segments: TamanhoFonte.values
                        .map((t) => ButtonSegment<TamanhoFonte>(
                              value: t,
                              label: Text(t.label),
                            ))
                        .toList(),
                    selected: {tamanho},
                    showSelectedIcon: false,
                    onSelectionChanged: (selecao) =>
                        ThemeService.definirTamanhoFonte(selecao.first),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
