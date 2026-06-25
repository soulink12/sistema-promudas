import 'package:flutter/material.dart';

/// Campo de texto obrigatório reutilizável.
///
/// Só sinaliza o erro (borda vermelha + texto "Obrigatório" abaixo do campo)
/// **depois** que o usuário focou o campo ao menos uma vez e o deixou em branco
/// — nunca antes da primeira interação. Conforme o usuário digita, o erro some.
///
/// Padrão oficial do projeto para indicar campos obrigatórios; aplicar nas
/// telas conforme formos mexendo nelas.
class CampoObrigatorio extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? prefixText;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool autofocus;
  // FocusNode externo (opcional). Se ausente, o widget cria/descarta o seu.
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  // Mensagem exibida quando o campo obrigatório fica vazio.
  final String mensagemErro;
  // Quando false, suprime o erro mesmo que o campo esteja vazio (ex.: o campo
  // deixou de ser exigido no contexto atual). O "tocado" continua sendo rastreado.
  final bool validar;
  // Força a exibição do erro mesmo sem o usuário ter tocado o campo — usado ao
  // tentar salvar o formulário (revela o que falta preencher).
  final bool mostrarErroForcado;

  const CampoObrigatorio({
    super.key,
    required this.controller,
    required this.label,
    this.prefixText,
    this.hintText,
    this.keyboardType,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.mensagemErro = 'Obrigatório',
    this.validar = true,
    this.mostrarErroForcado = false,
  });

  @override
  State<CampoObrigatorio> createState() => _CampoObrigatorioState();
}

class _CampoObrigatorioState extends State<CampoObrigatorio> {
  late final FocusNode _focusNode;
  // True quando o FocusNode é nosso (precisa de dispose).
  late final bool _focusNodeProprio;
  // Vira true assim que o usuário foca e sai do campo pela primeira vez.
  bool _tocado = false;

  @override
  void initState() {
    super.initState();
    _focusNodeProprio = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_aoMudarFoco);
    widget.controller.addListener(_aoMudarTexto);
  }

  // Ao perder o foco, libera a validação visual.
  void _aoMudarFoco() {
    if (!_focusNode.hasFocus && !_tocado) {
      setState(() => _tocado = true);
    }
  }

  // Re-renderiza para limpar/mostrar o erro conforme o usuário digita.
  void _aoMudarTexto() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_aoMudarFoco);
    widget.controller.removeListener(_aoMudarTexto);
    if (_focusNodeProprio) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vazio = widget.controller.text.trim().isEmpty;
    final mostrarErro =
        widget.validar && (_tocado || widget.mostrarErroForcado) && vazio;

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixText: widget.prefixText,
        border: const OutlineInputBorder(),
        isDense: true,
        errorText: mostrarErro ? widget.mensagemErro : null,
      ),
    );
  }
}
