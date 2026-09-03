import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/cpf_cnpj.dart';
import '../../../../core/widgets/dialog_confirmacao.dart';

class FormEdicaoCliente extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final bool salvando;
  final Future<void> Function(Map<String, dynamic> body) onSalvar;
  final VoidCallback onCancelar;

  const FormEdicaoCliente({
    super.key,
    required this.cliente,
    required this.salvando,
    required this.onSalvar,
    required this.onCancelar,
  });

  @override
  State<FormEdicaoCliente> createState() => _FormEdicaoClienteState();
}

class _FormEdicaoClienteState extends State<FormEdicaoCliente> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _cpf;
  late final TextEditingController _inscricao;
  late final TextEditingController _tel1;
  late final TextEditingController _tel2;
  late final TextEditingController _email;
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _bairro;
  late final TextEditingController _cidade;
  late final TextEditingController _estado;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nome = TextEditingController(text: c['nome'] as String? ?? '');
    _cpf = TextEditingController(
      text: formatarCpfCnpj(c['cpf_cnpj'] as String? ?? ''),
    );
    _inscricao = TextEditingController(
      text: c['inscricao_estadual'] as String? ?? '',
    );
    _tel1 = TextEditingController(text: c['telefone_1'] as String? ?? '');
    _tel2 = TextEditingController(text: c['telefone_2'] as String? ?? '');
    _email = TextEditingController(text: c['email'] as String? ?? '');
    _cep = TextEditingController(text: c['cep'] as String? ?? '');
    _logradouro = TextEditingController(text: c['logradouro'] as String? ?? '');
    _numero = TextEditingController(text: c['numero'] as String? ?? '');
    _bairro = TextEditingController(text: c['bairro'] as String? ?? '');
    _cidade = TextEditingController(text: c['cidade'] as String? ?? '');
    _estado = TextEditingController(text: c['estado'] as String? ?? 'PA');
  }

  @override
  void dispose() {
    for (final c in [
      _nome,
      _cpf,
      _inscricao,
      _tel1,
      _tel2,
      _email,
      _cep,
      _logradouro,
      _numero,
      _bairro,
      _cidade,
      _estado,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tentarSalvar() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Confirmar edição',
      mensagem:
          'Deseja salvar as alterações do cliente "${_nome.text.trim()}"?',
    );
    if (!confirmado) return;

    final body = <String, dynamic>{'nome': _nome.text.trim()};
    void add(String key, TextEditingController ctrl) {
      body[key] = ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null;
    }

    final cpfLimpo = limparCpfCnpj(_cpf.text);
    body['cpf_cnpj'] = cpfLimpo.isNotEmpty ? cpfLimpo : null;
    add('inscricao_estadual', _inscricao);
    add('telefone_1', _tel1);
    add('telefone_2', _tel2);
    add('email', _email);
    add('cep', _cep);
    add('logradouro', _logradouro);
    add('numero', _numero);
    add('bairro', _bairro);
    add('cidade', _cidade);
    add('estado', _estado);

    await widget.onSalvar(body);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editar Cliente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.salvando ? null : widget.onCancelar,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: widget.salvando ? null : _tentarSalvar,
                      child: widget.salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Salvar'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _campo(_nome, 'Nome *', obrigatorio: true),
                _subtitulo(context, 'Identificação'),
                _campo(
                  _cpf,
                  'CPF / CNPJ',
                  keyboardType: TextInputType.number,
                  inputFormatters: [CpfCnpjInputFormatter()],
                  validator: validarCampoCpfCnpj,
                ),
                _campo(_inscricao, 'Inscrição Estadual'),
                _subtitulo(context, 'Contato'),
                _campo(_tel1, 'Telefone'),
                _campo(_tel2, 'Telefone 2'),
                _campo(
                  _email,
                  'E-mail',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validarEmail,
                ),
                _subtitulo(context, 'Endereço'),
                Row(
                  children: [
                    Expanded(flex: 2, child: _campo(_cep, 'CEP')),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: _campo(_estado, 'Estado')),
                  ],
                ),
                _campo(_logradouro, 'Logradouro'),
                Row(
                  children: [
                    Expanded(flex: 3, child: _campo(_bairro, 'Bairro')),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _campo(_numero, 'Número')),
                  ],
                ),
                _campo(_cidade, 'Cidade'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// E-mail é opcional, mas quando preenchido precisa ter um formato válido —
// é a partir dele que o botão de "Enviar por e-mail" do PDF fica habilitado.
String? _validarEmail(String? v) {
  final texto = v?.trim() ?? '';
  if (texto.isEmpty) return null;
  final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto);
  return valido ? null : 'E-mail inválido.';
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

Widget _subtitulo(BuildContext context, String texto) {
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(
      texto.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    ),
  );
}

Widget _campo(
  TextEditingController controller,
  String label, {
  bool obrigatorio = false,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator:
          validator ??
          (obrigatorio
              ? (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
              : null),
    ),
  );
}
