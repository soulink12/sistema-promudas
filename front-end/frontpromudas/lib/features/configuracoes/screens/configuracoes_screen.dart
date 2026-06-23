import 'package:flutter/material.dart';
import '../../../core/services/theme_service.dart';

/// Tela de Aparência — preferências pessoais do operador (tema + tamanho da fonte).
/// É transversal aos módulos (acessível em PDV, Entregas e Administração), por isso
/// fica separada dos cadastros (Produtos/Formas), que pertencem à Administração.
class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração'),
      ),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeMode,
            builder: (context, mode, _) {
              return SwitchListTile(
                secondary: Icon(
                  mode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
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
