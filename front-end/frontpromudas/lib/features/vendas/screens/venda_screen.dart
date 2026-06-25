import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/carrinho_service.dart';
import '../../../core/theme/cores_semanticas.dart';
import '../../../core/utils/formatadores.dart';
import '../../clientes/screens/widgets/dialog_cadastro_cliente.dart';
import 'widgets/detalhes_app_bar.dart';
import 'widgets/modal_busca_cliente.dart';
import 'widgets/formulario_venda.dart';
import 'widgets/rodape_venda.dart';
import 'widgets/modal_pagamento.dart';
import 'widgets/dialog_observacoes.dart';
import 'widgets/drawer_pdv.dart';
import 'widgets/barra_atalhos.dart';
import '../../pedidos/screens/pedidos_screen.dart';
import '../../../core/services/pdf_download_service.dart';
import '../../../core/widgets/dialog_confirmacao.dart';

/// Tela principal de registro de venda (PDV).
/// Quando [pedidoParaEditar] é fornecido, entra em modo de edição: o carrinho
/// é pré-carregado com os itens do pedido e ao finalizar atualiza o pedido existente.
class TelaVenda extends StatefulWidget {
  final Map<String, dynamic>? pedidoParaEditar;

  const TelaVenda({super.key, this.pedidoParaEditar});

  @override
  State<TelaVenda> createState() => _TelaVendaState();
}

class _TelaVendaState extends State<TelaVenda> {
  // Cliente padrão para venda direta — id=1 reservado no banco para "Consumidor"
  final Map<String, dynamic> _consumidorPadrao = {
    'id': 1,
    'nome': 'Consumidor',
    'cpf': 'Não informado',
    'telefone': 'Não informado',
  };

  Map<String, dynamic>? _clienteSelecionado;
  final _carrinhoService = CarrinhoService();

  // Observações do pedido (campo livre, opcional) — enviado no POST/PUT
  String _observacoes = '';

  // Bloqueia interações enquanto o pedido está sendo enviado à API
  bool _salvando = false;

  // Total pago em pagamentos reais antes da edição (somente modo edição)
  double _totalPagoReal = 0.0;

  @override
  void initState() {
    super.initState();
    _clienteSelecionado = _consumidorPadrao;
    HardwareKeyboard.instance.addHandler(_onTecla);
    if (widget.pedidoParaEditar != null) {
      _preencherCarrinhoComPedido(widget.pedidoParaEditar!);
    }
  }

  void _preencherCarrinhoComPedido(Map<String, dynamic> pedido) {
    _observacoes = pedido['observacoes'] as String? ?? '';
    final cliente = pedido['clientes'];
    if (cliente != null) {
      _clienteSelecionado = {
        'id': cliente['id'],
        'nome': cliente['nome'] as String? ?? '—',
        'cpf': 'Não informado',
        'telefone': 'Não informado',
      };
    }

    final itens = (pedido['itens_pedido'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final item in itens) {
      final preco = _toDouble(item['valor_unitario']);
      _carrinhoService.adicionarItem(
        {
          'id': item['produto_id'],
          'nome': item['produtos']?['nome'] as String? ?? '—',
          'preco': preco,
        },
        quantidade: item['quantidade'] as int? ?? 1,
      );
    }

    final ajuste = _toDouble(pedido['ajuste']);
    if (ajuste.abs() > 0.001) {
      _carrinhoService.aplicarAjuste(
        ajuste,
        ajuste < 0 ? 'Desconto' : 'Acréscimo',
      );
    }

    final pagamentos = (pedido['pagamentos'] as List? ?? []);
    _totalPagoReal = pagamentos
        .where((p) => (p as Map)['pagamento_posterior'] != true)
        .fold(0.0, (s, p) => s + _toDouble((p as Map)['valor_pago']));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onTecla);
    super.dispose();
  }

  /// Intercepta atalhos da tela, independente de qual campo tem foco:
  /// F5 (buscar cliente), F12 (finalizar), Ctrl+C (cadastrar novo cliente)
  /// e Ctrl+E (pesquisar pedido).
  /// Só responde quando a TelaVenda é a rota atual — assim os atalhos não
  /// vazam para telas empilhadas por cima (Clientes, Pedidos, etc.).
  bool _onTecla(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_salvando) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _mostrarBuscaClienteModal(context);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f12) {
      _finalizarPedido();
      return true;
    }
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyC) {
      // Se houver texto selecionado, deixa o "copiar" nativo funcionar.
      if (_temTextoSelecionado()) return false;
      _mostrarCadastroCliente();
      return true;
    }
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyE) {
      _abrirPesquisaPedido();
      return true;
    }
    return false;
  }

  /// Abre a tela de pedidos para pesquisar (atalho Ctrl+E).
  void _abrirPesquisaPedido() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TelaPedidos()),
    );
  }

  /// Verifica se há texto selecionado no campo que está com foco no momento.
  /// Usado para não sobrescrever o "copiar" (Ctrl+C) quando há seleção ativa.
  bool _temTextoSelecionado() {
    final contextoFoco = FocusManager.instance.primaryFocus?.context;
    if (contextoFoco == null) return false;
    final editableText =
        contextoFoco.findAncestorStateOfType<EditableTextState>();
    final selecao = editableText?.textEditingValue.selection;
    return selecao != null && selecao.isValid && !selecao.isCollapsed;
  }

  /// Abre o modal de cadastro de novo cliente (atalho Ctrl+C).
  void _mostrarCadastroCliente() {
    showDialog<bool>(
      context: context,
      builder: (_) => const DialogCadastroCliente(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modoEdicao = widget.pedidoParaEditar != null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: DetalhesAppBar(
          clienteSelecionado: _clienteSelecionado,
          onTap: modoEdicao || _salvando
              ? null
              : () => _mostrarBuscaClienteModal(context),
          subtituloOverride: modoEdicao
              ? 'Editando Pedido ${formatarNumeroPedido(widget.pedidoParaEditar!)}'
              : null,
        ),
      ),
      drawer: modoEdicao ? null : const DrawerPdv(),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                if (modoEdicao) _buildBannerPagamento(),
                Expanded(
                  child: FormularioVendaWidget(
                    carrinho: _carrinhoService.itens,
                    ajuste: _carrinhoService.ajuste,
                    descricaoAjuste: _carrinhoService.descricaoAjuste,
                    ehPercentualAjuste: _carrinhoService.ehPercentualAjuste,
                    percentualAjuste: _carrinhoService.percentualAjuste,
                    onRemoverItem: (itemParaRemover) {
                      setState(() {
                        _carrinhoService.removerItem(itemParaRemover['id']);
                      });
                    },
                    onAlterarQuantidade: (item, novaQtd) {
                      setState(() {
                        _carrinhoService.alterarQuantidade(
                            item['id'], novaQtd);
                      });
                    },
                    onAlterarPreco: (item, novoPreco) {
                      setState(() {
                        _carrinhoService.alterarPreco(item['id'], novoPreco);
                      });
                    },
                    onFinalizarPedido: _finalizarPedido,
                    onAdicionarObservacoes: _editarObservacoes,
                    temObservacoes: _observacoes.isNotEmpty,
                    onAplicarAjuste: (valor, descricao,
                        {ehPercentual = false}) {
                      setState(() {
                        _carrinhoService.aplicarAjuste(valor, descricao,
                            ehPercentual: ehPercentual);
                      });
                    },
                    onRemoverAjuste: () {
                      setState(() {
                        _carrinhoService.removerAjuste();
                      });
                    },
                  ),
                ),
                RodapeVenda(onProdutoSelecionado: _adicionarAoCarrinho),
                const SizedBox(height: 8),
                const BarraAtalhos(),
              ],
            ),
          ),

          // Overlay de carregamento enquanto o pedido é enviado
          if (_salvando) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerPagamento() {
    if (_totalPagoReal < 0.01) return const SizedBox.shrink();
    final novoTotal = _carrinhoService.totalComAjuste;
    final diferenca = novoTotal - _totalPagoReal;
    final cs = Theme.of(context).colorScheme;

    final String label;
    final Color corFundo;
    final Color corTexto;

    if (diferenca > 0.01) {
      label = 'A receber: ${formatarMoeda(diferenca)}';
      corFundo = cs.primaryContainer;
      corTexto = cs.onPrimaryContainer;
    } else if (diferenca < -0.01) {
      label = 'Crédito: ${formatarMoeda(-diferenca)}';
      corFundo = cs.errorContainer;
      corTexto = cs.onErrorContainer;
    } else {
      label = 'Pedido quitado';
      corFundo = cs.secondaryContainer;
      corTexto = cs.onSecondaryContainer;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            'Já pago: ${formatarMoeda(_totalPagoReal)}',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: corTexto),
          ),
        ],
      ),
    );
  }

  void _mostrarBuscaClienteModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: BuscaClienteModal(
                onClienteSelecionado: (clienteEscolhido) {
                  setState(() {
                    _clienteSelecionado = clienteEscolhido;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _adicionarAoCarrinho(Map<String, dynamic> produto, int quantidade) {
    setState(() {
      _carrinhoService.adicionarItem(produto, quantidade: quantidade);
    });
  }

  /// Abre o diálogo de observações do pedido e guarda o resultado no estado.
  Future<void> _editarObservacoes() async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (_) => DialogObservacoes(observacoesAtuais: _observacoes),
    );
    if (resultado != null && mounted) {
      setState(() => _observacoes = resultado);
    }
  }

  void _finalizarPedido() {
    if (_carrinhoService.itens.isEmpty || _salvando) return;

    if (widget.pedidoParaEditar != null) {
      _confirmarEdicao();
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => ModalPagamento(
        totalPedido: _carrinhoService.totalComAjuste,
        onConfirmar: _registrarPedido,
      ),
    );
  }

  Future<void> _confirmarEdicao() async {
    final pedidoId = widget.pedidoParaEditar!['id'] as int;
    final confirmado = await mostrarDialogConfirmacao(
      context: context,
      titulo: 'Confirmar edição',
      mensagem:
          'Deseja salvar as alterações no Pedido ${formatarNumeroPedido(widget.pedidoParaEditar!)}?',
      textoConfirmar: 'Salvar',
    );
    if (!confirmado || !mounted) return;
    _salvarEdicao(pedidoId);
  }

  Future<void> _salvarEdicao(int pedidoId) async {
    setState(() => _salvando = true);

    final itens = _carrinhoService.itens;
    final ajuste = _carrinhoService.ajuste;

    try {
      final response = await ApiService.dio.put('/pedidos/$pedidoId', data: {
        'itens': itens
            .map((item) => {
                  'produto_id': item['id'],
                  'quantidade': item['quantidade'],
                  'valor_unitario': item['preco'],
                })
            .toList(),
        'ajuste': ajuste != 0.0 ? ajuste : null,
        'observacoes': _observacoes.isNotEmpty ? _observacoes : null,
      });

      final creditoGerado = _toDouble(response.data['creditoGerado']);
      setState(() => _salvando = false);

      if (mounted) {
        final mensagem = creditoGerado > 0.01
            ? 'Pedido atualizado. Crédito de ${formatarMoeda(creditoGerado)} adicionado ao cliente.'
            : 'Pedido atualizado com sucesso!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: creditoGerado > 0.01
                ? CoresSemanticas.aviso
                : CoresSemanticas.sucesso,
            duration: Duration(seconds: creditoGerado > 0.01 ? 5 : 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar pedido. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Envia o pedido à API: cria o pedido com os itens e registra cada pagamento.
  /// Troco é ignorado — o valor de cada parcela é capeado pelo saldo restante.
  Future<void> _registrarPedido(
      List<Map<String, dynamic>> pagamentos) async {
    setState(() => _salvando = true);

    final itens = _carrinhoService.itens;
    final cliente = _clienteSelecionado!;
    final ajuste = _carrinhoService.ajuste;

    try {
      // 1. Cria o pedido com os itens
      final respostaPedido = await ApiService.dio.post('/pedidos', data: {
        'cliente_id': cliente['id'],
        'valor_total': _carrinhoService.totalComAjuste,
        if (ajuste != 0.0) 'ajuste': ajuste,
        if (_observacoes.isNotEmpty) 'observacoes': _observacoes,
        'itens': itens
            .map((item) => {
                  'produto_id': item['id'],
                  'quantidade': item['quantidade'],
                  'valor_unitario': item['preco'],
                })
            .toList(),
      });

      final pedidoId = respostaPedido.data['data']['id'] as int;

      // 2. Registra cada forma de pagamento, capeando pelo saldo restante (descarta troco)
      double restante = _carrinhoService.totalComAjuste;
      for (final p in pagamentos) {
        if (restante <= 0.005) break;
        final valorPago =
            (p['valor'] as double).clamp(0.0, restante);
        await ApiService.dio.post('/pagamentos', data: {
          'pedido_id': pedidoId,
          'valor_pago': valorPago,
          'forma_pagamento': p['forma'],
          // Cheque (depósito posterior): data fica nula até o depósito.
          if (p['depositoPosterior'] != true)
            'data_pagamento': DateTime.now().toUtc().toIso8601String(),
          if (p['parcelas'] != null) 'parcelas': p['parcelas'],
          if (p['escamboQuantidade'] != null)
            'escambo_quantidade': p['escamboQuantidade'],
          if (p['conta'] != null) 'conta': p['conta'],
          if (p['nomePagador'] != null) 'nome_pagador': p['nomePagador'],
          if (p['cpfPagador'] != null) 'cpf_cnpj_pagador': p['cpfPagador'],
          if (p['cheques'] != null) 'cheques': p['cheques'],
        });
        restante -= valorPago;
      }

      // 3. Reinicia o estado da tela
      setState(() {
        _carrinhoService.limpar();
        _clienteSelecionado = _consumidorPadrao;
        _observacoes = '';
        _salvando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido registrado com sucesso!'),
            backgroundColor: CoresSemanticas.sucesso,
          ),
        );
        await PdfDownloadService.baixarESalvar(context, pedidoId);
      }
    } catch (_) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar pedido. Tente novamente.'),
            backgroundColor: CoresSemanticas.erro,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
