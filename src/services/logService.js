const fs = require('fs');
const path = require('path');
const prisma = require('../config/database');

const PASTA_LOGS = process.env.LOG_DIR || path.join(__dirname, '..', '..', 'logs');
try { fs.mkdirSync(PASTA_LOGS, { recursive: true }); } catch (_) { /* já existe */ }

const PAGE_SIZE_PADRAO = 50;
const PAGE_SIZE_MAXIMO = 200;
const LIMITE_EXPORTACAO = 5000;

const arquivoDoDia = (prefixo) => {
    const hoje = new Date().toISOString().slice(0, 10);
    return path.join(PASTA_LOGS, `${prefixo}-${hoje}.log`);
};

// Append assíncrono, sem esperar — nunca deve atrasar nem derrubar quem chamou.
const escreverLinha = (prefixo, objeto) => {
    const linha = JSON.stringify({ timestamp: new Date().toISOString(), ...objeto }) + '\n';
    fs.appendFile(arquivoDoDia(prefixo), linha, (erro) => {
        if (erro) console.error('Falha ao escrever log em arquivo:', erro);
    });
};

const paginacao = (filtros) => {
    const page = Number.isInteger(filtros.page) && filtros.page > 0 ? filtros.page : 1;
    const pageSizeBruto = Number.isInteger(filtros.pageSize) && filtros.pageSize > 0 ? filtros.pageSize : PAGE_SIZE_PADRAO;
    const pageSize = Math.min(pageSizeBruto, PAGE_SIZE_MAXIMO);
    return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
};

const filtroData = (filtros) => {
    const criado_em = {};
    if (filtros.de) criado_em.gte = new Date(filtros.de);
    if (filtros.ate) criado_em.lte = new Date(filtros.ate);
    return Object.keys(criado_em).length > 0 ? criado_em : undefined;
};

// Grava um evento de atividade (CRUD de negócio). Passe `tx` quando a operação
// roda dentro de uma transação Prisma — deve ser a ÚLTIMA chamada dentro da
// transação, para minimizar a janela em que o arquivo já registrou algo que
// depois sofre rollback (só um erro no próprio COMMIT causaria essa
// inconsistência, aceitável dado o baixo volume do sistema).
const registrarAtividade = async (tx, { usuarioId, acao, entidade, entidadeId, snapshot }) => {
    const client = tx || prisma;
    const registro = await client.logs_atividade.create({
        data: {
            usuario_id: usuarioId ?? null,
            acao,
            entidade,
            entidade_id: entidadeId ?? null,
            snapshot: snapshot ?? undefined,
        },
    });
    // Arquivo só guarda metadado leve — o snapshot tem dado de cliente
    // (CPF, endereço), mantido fora de um arquivo texto sem controle de acesso.
    escreverLinha('atividade', { usuarioId: usuarioId ?? null, acao, entidade, entidadeId: entidadeId ?? null });
    return registro;
};

// Grava um erro real do sistema. Nunca lança — chamado de dentro de
// errorHandler/unhandledRejection/uncaughtException, onde propagar geraria loop.
const registrarErro = async ({ usuarioId, mensagem, stack, rota, metodoHttp, statusCode, origem }) => {
    try {
        await prisma.logs_erro.create({
            data: {
                usuario_id: usuarioId ?? null,
                mensagem: String(mensagem ?? '').slice(0, 5000),
                stack: stack ? String(stack).slice(0, 8000) : null,
                rota: rota ?? null,
                metodo_http: metodoHttp ?? null,
                status_code: statusCode ?? null,
                origem,
            },
        });
    } catch (erroSecundario) {
        console.error('Falha ao persistir log de erro no banco:', erroSecundario);
    }
    escreverLinha('erro', { origem, rota: rota ?? null, metodoHttp: metodoHttp ?? null, statusCode: statusCode ?? null, mensagem });
};

const listarAtividades = async (filtros = {}) => {
    const { page, pageSize, skip, take } = paginacao(filtros);
    const where = {
        entidade: filtros.entidade || undefined,
        entidade_id: filtros.entidadeId ? Number(filtros.entidadeId) : undefined,
        usuario_id: filtros.usuarioId ? Number(filtros.usuarioId) : undefined,
        acao: filtros.acao || undefined,
        criado_em: filtroData(filtros),
    };
    const [dados, total] = await Promise.all([
        prisma.logs_atividade.findMany({
            where,
            orderBy: { criado_em: 'desc' },
            skip,
            take,
            include: { usuarios: { select: { nome: true } } },
        }),
        prisma.logs_atividade.count({ where }),
    ]);
    return { dados, total, page, pageSize };
};

// Campos que sempre mudam entre eventos sem representar uma alteração de
// negócio relevante: o timestamp do snapshot, e o `id` da própria linha (na
// raiz é sempre a mesma entidade, nunca muda; ver CAMPOS_IGNORADOS_ITEM pros
// itens, que têm uma razão adicional pra ignorar mais campos).
const CAMPOS_IGNORADOS_DIFF = new Set(['criado_em', 'atualizado_em', 'id']);

// Além do id, ao comparar ITENS (itens_pedido/itens_orcamento) também ignora
// a FK pro pai (pedido_id/orcamento_id — sempre a mesma dentro da mesma
// entidade, óbvio demais pra ser um "campo alterado"). `pedido_id` também
// aparece na RAIZ de um orçamento aprovado (liga o orçamento ao pedido
// criado) — ali É uma mudança relevante, por isso este ignore fica separado
// do CAMPOS_IGNORADOS_DIFF geral, só usado dentro de diferencaListaDeItens.
const CAMPOS_IGNORADOS_ITEM = new Set([...CAMPOS_IGNORADOS_DIFF, 'pedido_id', 'orcamento_id']);

// "Lista de itens" reconhecível (itens_pedido, itens_orcamento): array onde
// cada elemento é um objeto com `produto_id` — permite comparar item a item
// em vez de tratar a lista inteira como um valor opaco.
const éListaDeItensComProduto = (valor) =>
    Array.isArray(valor) && valor.length > 0 && valor.every((item) => item && typeof item === 'object' && 'produto_id' in item);

// Chave de identidade de um item pro diff: produto_id, não o `id` da linha —
// como toda edição com itens apaga e recria as linhas (ver comentário acima),
// o `id` nunca sobrevive entre dois eventos mesmo quando o item "é o mesmo".
// Assume no máximo uma linha por produto no pedido/orçamento (é como o PDV
// monta os itens); se houver duas linhas do mesmo produto, uma delas cai no
// mesmo balde da outra e o diff fica menos preciso nesse caso raro.
const chaveDoItem = (item) => `produto:${item.produto_id}`;

// Compara duas listas de itens pelo produto: item só de um lado = adicionado/
// removido; item nos dois lados com conteúdo diferente (quantidade, valor
// unitário) = alterado (com o diff campo a campo dele, recursivo).
const diferencaListaDeItens = (listaAnterior, listaAtual) => {
    const mapaAnterior = new Map((listaAnterior ?? []).map((item) => [chaveDoItem(item), item]));
    const mapaAtual = new Map((listaAtual ?? []).map((item) => [chaveDoItem(item), item]));
    const todasChaves = new Set([...mapaAnterior.keys(), ...mapaAtual.keys()]);
    const itens = [];
    for (const chave of todasChaves) {
        const antes = mapaAnterior.get(chave);
        const depois = mapaAtual.get(chave);
        if (antes && !depois) {
            itens.push({ tipo: 'removido', item: antes });
        } else if (!antes && depois) {
            itens.push({ tipo: 'adicionado', item: depois });
        } else {
            const camposAlterados = calcularDiferencas(antes, depois, CAMPOS_IGNORADOS_ITEM) ?? [];
            if (camposAlterados.length > 0) {
                itens.push({ tipo: 'alterado', antes, depois, camposAlterados });
            }
        }
    }
    return itens;
};

// Compara o snapshot deste evento com o do evento anterior da mesma entidade
// (que é exatamente o estado "antes" desta mudança, já que toda mutação
// passa por registrarAtividade). Campos escalares viram `{ tipo: 'campo' }`;
// listas de itens (itens_pedido/itens_orcamento) viram `{ tipo: 'lista' }`
// com o diff item a item.
const calcularDiferencas = (anterior, atual, camposIgnorados = CAMPOS_IGNORADOS_DIFF) => {
    if (!anterior || !atual) return null;
    const chaves = new Set([...Object.keys(anterior), ...Object.keys(atual)]);
    const diferencas = [];
    for (const chave of chaves) {
        if (camposIgnorados.has(chave)) continue;
        const valorAnterior = anterior[chave];
        const valorAtual = atual[chave];
        // Campo ausente num dos dois eventos (ex.: itens_pedido não incluído
        // numa atualização que só mexeu em metadados) — não dá pra saber se
        // mudou, então não afirma uma mudança falsa.
        if (valorAnterior === undefined || valorAtual === undefined) continue;

        if (éListaDeItensComProduto(valorAnterior) || éListaDeItensComProduto(valorAtual)) {
            const itens = diferencaListaDeItens(valorAnterior, valorAtual);
            if (itens.length > 0) {
                diferencas.push({ campo: chave, tipo: 'lista', itens });
            }
            continue;
        }

        if (JSON.stringify(valorAnterior ?? null) !== JSON.stringify(valorAtual ?? null)) {
            diferencas.push({ campo: chave, tipo: 'campo', de: valorAnterior ?? null, para: valorAtual ?? null });
        }
    }
    return diferencas;
};

const buscarAtividade = async (id) => {
    const atividade = await prisma.logs_atividade.findUnique({
        where: { id: Number(id) },
        include: { usuarios: { select: { nome: true } } },
    });
    if (!atividade) return null;

    // Evento anterior da MESMA entidade (não do registro como um todo) — é o
    // estado imediatamente antes deste evento.
    let snapshotAnterior = null;
    if (atividade.entidade_id != null) {
        const anterior = await prisma.logs_atividade.findFirst({
            where: {
                entidade: atividade.entidade,
                entidade_id: atividade.entidade_id,
                id: { lt: atividade.id },
            },
            orderBy: { id: 'desc' },
            select: { snapshot: true },
        });
        snapshotAnterior = anterior?.snapshot ?? null;
    }

    return {
        ...atividade,
        snapshot_anterior: snapshotAnterior,
        diferencas: calcularDiferencas(snapshotAnterior, atividade.snapshot),
    };
};

const listarErros = async (filtros = {}) => {
    const { page, pageSize, skip, take } = paginacao(filtros);
    const where = {
        criado_em: filtroData(filtros),
    };
    const [dados, total] = await Promise.all([
        prisma.logs_erro.findMany({
            where,
            orderBy: { criado_em: 'desc' },
            skip,
            take,
            select: {
                id: true,
                usuario_id: true,
                origem: true,
                mensagem: true,
                rota: true,
                metodo_http: true,
                status_code: true,
                criado_em: true,
                usuarios: { select: { nome: true } },
            },
        }),
        prisma.logs_erro.count({ where }),
    ]);
    return { dados, total, page, pageSize };
};

const buscarErro = async (id) => prisma.logs_erro.findUnique({
    where: { id: Number(id) },
    include: { usuarios: { select: { nome: true } } },
});

const escaparCampoCSV = (valor) => {
    const texto = valor === null || valor === undefined ? '' : String(valor);
    if (/[",\n]/.test(texto)) {
        return `"${texto.replace(/"/g, '""')}"`;
    }
    return texto;
};

const gerarExportacaoCSV = async (filtros = {}) => {
    const { dados } = await listarAtividades({ ...filtros, page: 1, pageSize: LIMITE_EXPORTACAO });
    const cabecalho = ['id', 'data', 'usuario', 'acao', 'entidade', 'entidade_id'];
    const linhas = dados.map((item) => [
        item.id,
        item.criado_em.toISOString(),
        item.usuarios?.nome ?? '',
        item.acao,
        item.entidade,
        item.entidade_id ?? '',
    ].map(escaparCampoCSV).join(','));
    return [cabecalho.join(','), ...linhas].join('\n');
};

module.exports = {
    registrarAtividade,
    registrarErro,
    listarAtividades,
    buscarAtividade,
    listarErros,
    buscarErro,
    gerarExportacaoCSV,
    PASTA_LOGS,
};
