import 'package:flutter/material.dart';

/// Diálogo para registrar/editar manualmente a nota fiscal de um pagamento.
/// Retorna via `Navigator.pop` `{status_nota, numero_nota, data_emissao_nota}`
/// ao salvar, ou `null` se cancelado. Quem chama persiste via PUT.
class DialogNotaFiscal extends StatefulWidget {
  final Map<String, dynamic> pagamento;

  const DialogNotaFiscal({super.key, required this.pagamento});

  @override
  State<DialogNotaFiscal> createState() => _DialogNotaFiscalState();
}

class _DialogNotaFiscalState extends State<DialogNotaFiscal> {
  static const _statusValidos = ['Pendente', 'Emitida', 'Rejeitada', 'Processando'];

  String _status = 'Pendente';
  final _numeroCtrl = TextEditingController();
  DateTime? _dataEmissao;

  @override
  void initState() {
    super.initState();
    final st = widget.pagamento['status_nota'] as String?;
    if (st != null && _statusValidos.contains(st)) _status = st;
    _numeroCtrl.text = widget.pagamento['numero_nota'] as String? ?? '';
    final dataIso = widget.pagamento['data_emissao_nota'];
    _dataEmissao = DateTime.tryParse(dataIso?.toString() ?? '')?.toUtc();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  bool get _emitida => _status == 'Emitida';

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataEmissao ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data != null) setState(() => _dataEmissao = data);
  }

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  bool get _podeSalvar {
    // Quando emitida, exige número e data de emissão
    if (_emitida) {
      return _numeroCtrl.text.trim().isNotEmpty && _dataEmissao != null;
    }
    return true;
  }

  void _salvar() {
    final numero = _numeroCtrl.text.trim();
    // Número e data só fazem sentido quando a nota foi emitida
    final d = _dataEmissao;
    Navigator.pop(context, <String, dynamic>{
      'status_nota': _status,
      'numero_nota': _emitida && numero.isNotEmpty ? numero : null,
      'data_emissao_nota': _emitida && d != null
          ? DateTime.utc(d.year, d.month, d.day).toIso8601String()
          : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nota Fiscal'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status da nota',
                border: OutlineInputBorder(),
              ),
              items: _statusValidos
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'Pendente'),
            ),
            if (_emitida) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _numeroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número da nota',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarData,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de emissão',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(
                    _dataEmissao != null
                        ? _formatarData(_dataEmissao!)
                        : 'Selecionar data',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _podeSalvar ? _salvar : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
