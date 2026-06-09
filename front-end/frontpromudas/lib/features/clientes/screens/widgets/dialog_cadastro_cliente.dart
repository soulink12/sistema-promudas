import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';

class DialogCadastroCliente extends StatefulWidget {
  const DialogCadastroCliente({super.key});

  @override
  State<DialogCadastroCliente> createState() => _DialogCadastroClienteState();
}

class _DialogCadastroClienteState extends State<DialogCadastroCliente> {
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  String? _erro;

  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _inscricao = TextEditingController();
  final _tel1 = TextEditingController();
  final _tel2 = TextEditingController();
  final _cep = TextEditingController();
  final _logradouro = TextEditingController();
  final _numero = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _estado = TextEditingController(text: 'PA');

  @override
  void dispose() {
    for (final c in [
      _nome, _cpf, _inscricao, _tel1, _tel2, _cep,
      _logradouro, _numero, _bairro, _cidade, _estado,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final body = <String, dynamic>{'nome': _nome.text.trim()};
      void add(String key, TextEditingController c) {
        if (c.text.trim().isNotEmpty) body[key] = c.text.trim();
      }
      add('cpf_cnpj', _cpf);
      add('inscricao_estadual', _inscricao);
      add('telefone_1', _tel1);
      add('telefone_2', _tel2);
      add('cep', _cep);
      add('logradouro', _logradouro);
      add('numero', _numero);
      add('bairro', _bairro);
      add('cidade', _cidade);
      add('estado', _estado);

      await ApiService.dio.post('/clientes', data: body);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() {
        _erro = 'Erro ao cadastrar cliente. Tente novamente.';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Novo Cliente',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campo(_nome, 'Nome *', obrigatorio: true),
                      _subtitulo('Identificação'),
                      _campo(_cpf, 'CPF / CNPJ'),
                      _campo(_inscricao, 'Inscrição Estadual'),
                      _subtitulo('Contato'),
                      _campo(_tel1, 'Telefone'),
                      _campo(_tel2, 'Telefone 2'),
                      _subtitulo('Endereço'),
                      Row(children: [
                        Expanded(flex: 2, child: _campo(_cep, 'CEP')),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 3, child: _campo(_estado, 'Estado')),
                      ]),
                      _campo(_logradouro, 'Logradouro'),
                      Row(children: [
                        Expanded(
                            flex: 3, child: _campo(_bairro, 'Bairro')),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 1, child: _campo(_numero, 'Número')),
                      ]),
                      _campo(_cidade, 'Cidade'),
                      if (_erro != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_erro!,
                              style:
                                  const TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

Widget _subtitulo(String texto) {
  return Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      texto.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.8),
    ),
  );
}

Widget _campo(TextEditingController controller, String label,
    {bool obrigatorio = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: obrigatorio
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
          : null,
    ),
  );
}
