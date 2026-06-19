import 'package:flutter/material.dart';
import '../../../core/services/theme_service.dart';
import 'formas_pagamento_screen.dart';
import 'produtos_screen.dart';

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
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          _buildSecao(context, 'Aparência'),
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
          _buildSecao(context, 'Cadastros'),
          ListTile(
            leading: const Icon(Icons.eco_outlined),
            title: const Text('Produtos'),
            subtitle: const Text('Adicionar, editar ou desativar produtos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaProdutos()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payment_outlined),
            title: const Text('Formas de Pagamento'),
            subtitle: const Text('Adicionar, editar ou remover formas de pagamento'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TelaFormasPagamento()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecao(BuildContext context, String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
