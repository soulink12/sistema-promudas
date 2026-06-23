import 'package:flutter/material.dart';
import '../../../core/services/theme_service.dart';
import 'produtos_screen.dart';
import 'formas_pagamento_screen.dart';

/// Tela de Configuração — preferências de aparência (tema + tamanho da fonte) e
/// os cadastros do sistema (produtos e formas de pagamento). Acessada pela
/// Administração.
class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  void _abrir(Widget tela) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração')),
      body: ListView(
        children: [
          _CabecalhoSecao(texto: 'APARÊNCIA'),
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
          const Divider(),
          _CabecalhoSecao(texto: 'CADASTROS'),
          ListTile(
            leading: Icon(Icons.eco_outlined, color: cs.primary),
            title: const Text('Produtos'),
            subtitle: const Text('Adicionar, editar ou desativar produtos.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(const TelaProdutos()),
          ),
          ListTile(
            leading: Icon(Icons.payment_outlined, color: cs.primary),
            title: const Text('Formas de Pagamento'),
            subtitle: const Text('Adicionar, editar ou remover formas de pagamento.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrir(const TelaFormasPagamento()),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de seção (texto pequeno em caixa, cor primária) das listas de config.
class _CabecalhoSecao extends StatelessWidget {
  final String texto;
  const _CabecalhoSecao({required this.texto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: cs.primary,
        ),
      ),
    );
  }
}
