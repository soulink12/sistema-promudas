import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/formatadores.dart';
import 'clientes_screen.dart';

/// Lista, em ordem crescente pelo sequencial do ID da Temporada, os clientes
/// que já têm esse campo preenchido — referência de migração do controle em
/// papel para o sistema. Toque num item abre os detalhes do cliente.
class TelaClientesPorTemporada extends StatefulWidget {
  const TelaClientesPorTemporada({super.key});

  @override
  State<TelaClientesPorTemporada> createState() =>
      _TelaClientesPorTemporadaState();
}

class _TelaClientesPorTemporadaState extends State<TelaClientesPorTemporada> {
  List<Map<String, dynamic>> _clientes = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final response = await ApiService.dio.get('/clientes/por-temporada');
      final lista = (response.data as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() {
          _clientes = lista;
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar clientes. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
          ),
        );
      }
    }
  }

  void _abrirCliente(Map<String, dynamic> cliente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaListaClientes(clienteInicialId: cliente['id'] as int),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes por ID de Temporada')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _clientes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag, size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum cliente com ID de Temporada cadastrado.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _clientes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CardClienteTemporada(
                      cliente: _clientes[i],
                      onTap: () => _abrirCliente(_clientes[i]),
                    ),
                  ),
                ),
    );
  }
}

class _CardClienteTemporada extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final VoidCallback onTap;

  const _CardClienteTemporada({required this.cliente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nome = capitalizarNome(cliente['nome'] as String? ?? '');
    final idTemporada = cliente['id_temporada'] as String? ?? '—';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              idTemporada,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
