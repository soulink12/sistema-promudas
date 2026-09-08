# Sistema Promudas

App de gestão para o Viveiro Promudas (venda de mudas): clientes, pedidos,
pagamentos, entregas, orçamentos.

## Stack

- **Backend**: Node.js + Express 5, Prisma ORM 7 (`@prisma/adapter-mariadb`,
  MySQL/MariaDB), JWT (`jsonwebtoken`/`bcrypt`), PDF via `pdfkit`, e-mail via
  `resend`. Entrada: `src/server.js` (porta padrão 6072).
- **Frontend**: Flutter desktop (`front-end/frontpromudas`), Material 3,
  ColorScheme semeado em verde. Sem tabela de rotas nomeada — navegação via
  `Navigator.push(MaterialPageRoute(...))`.
- **Padrão de camada no backend**: `routes/` → `controllers/` → `services/`
  (services concentram a lógica/Prisma). Erros de negócio usam
  `BusinessError` (`src/utils/BusinessError.js`), tratados em
  `src/middlewares/errorHandler.js`.
- **Padrão no frontend**: cada tela "lista + detalhe" (ex.: Pedidos) é um
  `StatefulWidget` que guarda `_itemSelecionado`; ao selecionar, troca o
  corpo pra um widget de detalhes (`Detalhes*.dart`), sem rota separada.
  Toda a lógica de API fica no `State` da tela — os widgets de detalhe são
  `StatelessWidget` recebendo dados + callbacks. Não há uma camada de
  "service" para todo recurso (pedido não tem `pedido_service.dart`; as
  chamadas ficam direto em `pedidos_screen.dart` via `ApiService.dio`).

## Estado atual (branch `claude/sistema-promudas-ultima-atualizacao-e1sn3j`, PR #2)

Duas features implementadas (backend + frontend), aguardando teste local do
usuário antes do merge — **não fazer merge sem confirmação dele**.

### 1. Enviar PDF do pedido/orçamento por e-mail

- `clientes.email` (novo campo, opcional) — cadastro/edição em
  `front-end/.../clientes/screens/widgets/dialog_cadastro_cliente.dart` e
  `form_edicao_cliente.dart`.
- `src/services/emailService.js`: envia um PDF (buffer) por e-mail via
  Resend. Usa `process.env.RESEND_API_KEY` e `EMAIL_REMETENTE`.
- `POST /api/pedidos/:id/enviar-email` e `POST /api/orcamentos/:id/enviar-email`.
- Botão de enviar por e-mail em `core/widgets/pdf_preview_screen.dart`
  (tela de preview do PDF, compartilhada entre pedido e orçamento) — só
  habilita se o cliente tiver e-mail. Lógica de confirmar+enviar
  centralizada em `core/utils/enviar_email_documento.dart` (reusada
  também na tela de detalhes do orçamento, que manda o e-mail direto sem
  precisar abrir o PDF).

### 2. Módulo de Orçamentos

Documento prévio ligado a um cliente, com os mesmos itens de um pedido, mas
sem pagamento/entrega. Numeração própria simples: sempre `#id` (sem
temporada, diferente do pedido).

- Models `orcamentos`/`itens_orcamento` em `prisma/schema.prisma`
  (paralelos a `pedidos`/`itens_pedido`). `orcamentos.status`:
  `Pendente` (default) | `Aprovado` | `Rejeitado`. `orcamentos.pedido_id`
  é preenchido só quando aprovado.
- `src/services/orcamentoService.js` espelha `pedidoService.js`: CRUD,
  `aprovarOrcamento` (transação: cria um `pedido` de verdade — sem
  pagamento/entrega ainda — e marca o orçamento como Aprovado, vinculado
  ao pedido criado), `recusarOrcamento` (só muda status).
- `src/services/pdfService.js`: `gerarOrcamentoPDF` ao lado do
  `gerarPedidoPDF` existente (mesmo estilo visual, sem seções de
  pagamento/entrega).
- Frontend: novo módulo `front-end/.../features/orcamentos/` (lista +
  detalhes, espelhando `features/pedidos/`). Detalhes do orçamento: botões
  Recusar/Aprovar (com diálogo de confirmação antes de agir — Recusar à
  esquerda, Aprovar à direita), Emitir PDF, Enviar por E-mail, menu "⋮"
  com Editar/Excluir. Aprovado mostra link para o pedido gerado.
- `venda_screen.dart` (tela de venda/PDV, já usada para criar/editar
  pedido) ganhou `orcamentoParaEditar` — **F11** cria um orçamento novo ou
  salva as alterações de um orçamento em edição; **F12** continua
  criando/editando pedido normalmente, sem mudanças de comportamento.
- Novo item "Orçamentos" no drawer (`drawer_pdv.dart`).

## Pendências / o que testar

- **Nunca rodei isso de verdade**: o ambiente onde essa feature foi
  desenvolvida não tinha MySQL nem Flutter instalados — só validei o
  backend com `node -c`/carregamento dos módulos, e revisei o Dart
  manualmente (sem `flutter analyze`/build). É bem possível que apareça
  algo quebrado ao compilar/rodar de verdade.
- `.env` do backend precisa de, além do já existente
  (`DATABASE_URL`, `DATABASE_HOST/USER/PASSWORD/NAME/PORT`, `JWT_SECRET`,
  `PORT`): `RESEND_API_KEY` e `EMAIL_REMETENTE` (endereço "from", precisa
  de domínio verificado na Resend). Sem isso, cadastro de e-mail e os
  botões funcionam normalmente — só o envio de verdade falha com erro
  claro.
- Migration já criada e commitada:
  `prisma/migrations/20260903160426_add_email_cliente_e_orcamentos`. Rodar
  `npx prisma migrate deploy` (não `migrate dev`, pra não tentar criar uma
  migration nova).
- Checklist de teste manual: cadastrar cliente com e-mail → emitir PDF de
  pedido → botão de e-mail habilitado → confirmar envio; criar orçamento
  (F11) → editar (F11 de novo) → aprovar (confere que criou um pedido) →
  recusar outro; conferir listagem/filtro de orçamentos por status.

## Referência rápida

- Pedido é o "molde" pro orçamento em tudo — qualquer dúvida de como algo
  deveria se comportar no orçamento, olhar o equivalente em
  `pedidoService.js`/`pedidoController.js`/`pedidos_screen.dart`/
  `detalhes_pedido.dart` primeiro.
- PR aberta (draft) com a descrição completa das mudanças:
  https://github.com/soulink12/sistema-promudas/pull/2
