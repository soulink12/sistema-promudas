const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { limpar, validar } = require('../utils/cpfCnpj');
const logService = require('./logService');

// Normaliza cpf_cnpj para só dígitos, valida o dígito verificador e checa
// duplicidade. `idExcluir` evita que um cliente colida consigo mesmo ao
// editar sem trocar o próprio CPF/CNPJ. Não faz nada se a chave nem foi
// enviada no body (undefined); string vazia/null limpa o campo.
const normalizarCpfCnpj = async (dados, idExcluir) => {
    if (dados.cpf_cnpj === undefined) return;
    const valorLimpo = limpar(dados.cpf_cnpj ?? '');
    if (!valorLimpo) {
        dados.cpf_cnpj = null;
        return;
    }
    if (!validar(valorLimpo)) {
        throw new BusinessError('CPF/CNPJ inválido.');
    }
    const existente = await prisma.clientes.findFirst({
        where: {
            cpf_cnpj: valorLimpo,
            ...(idExcluir ? { id: { not: idExcluir } } : {}),
        },
    });
    if (existente) {
        throw new BusinessError('Já existe um cliente cadastrado com esse CPF/CNPJ.');
    }
    dados.cpf_cnpj = valorLimpo;
};

// Normaliza cep para só dígitos e valida o tamanho (8 dígitos). Não faz nada
// se a chave nem foi enviada no body (undefined); string vazia/null limpa o campo.
const normalizarCep = (dados) => {
    if (dados.cep === undefined) return;
    const valorLimpo = String(dados.cep ?? '').replace(/\D/g, '');
    if (!valorLimpo) {
        dados.cep = null;
        return;
    }
    if (valorLimpo.length !== 8) {
        throw new BusinessError('CEP inválido.');
    }
    dados.cep = valorLimpo;
};

// Formato do ID da Temporada: "<temporada>-<sequencial>", ambos numéricos
// (ex.: 27-1) — é o número que o viveiro já usava no controle em papel.
const FORMATO_ID_TEMPORADA = /^\d+-\d+$/;

// Normaliza id_temporada (texto livre digitado à mão), valida o formato
// "NN-XXX" e checa duplicidade — mesmo padrão de normalizarCpfCnpj. Não faz
// nada se a chave nem foi enviada no body (undefined); string vazia/null
// limpa o campo.
const normalizarIdTemporada = async (dados, idExcluir) => {
    if (dados.id_temporada === undefined) return;
    const valor = String(dados.id_temporada ?? '').trim();
    if (!valor) {
        dados.id_temporada = null;
        return;
    }
    if (!FORMATO_ID_TEMPORADA.test(valor)) {
        throw new BusinessError('ID da Temporada inválido. Use o formato "27-1" (temporada-sequencial).');
    }
    const existente = await prisma.clientes.findFirst({
        where: {
            id_temporada: valor,
            ...(idExcluir ? { id: { not: idExcluir } } : {}),
        },
    });
    if (existente) {
        throw new BusinessError('Já existe um cliente cadastrado com esse ID de Temporada.');
    }
    dados.id_temporada = valor;
};

// Campos que o cliente da API pode gravar. Fora daqui ficam `saldo_credito`
// (só o backend mexe, ao editar pedido pago) e `ativo` (gerido pelo
// soft-delete): antes o req.body ia inteiro pro Prisma, então um PUT com
// {"saldo_credito": 99999} gravava e {"ativo": true} ressuscitava cliente apagado.
const CAMPOS_CLIENTE_EDITAVEIS = [
    'nome',
    'cpf_cnpj',
    'inscricao_estadual',
    'id_temporada',
    'telefone_1',
    'telefone_2',
    'email',
    'cep',
    'logradouro',
    'numero',
    'bairro',
    'cidade',
    'estado',
];

const filtrarCamposCliente = (dadosCliente) => Object.fromEntries(
    Object.entries(dadosCliente).filter(([chave]) => CAMPOS_CLIENTE_EDITAVEIS.includes(chave))
);

// Guarda telefone só com dígitos, como cpf_cnpj e cep — a máscara é aplicada
// na exibição (formatarTelefone). Sem validar tamanho de propósito: número
// antigo/incompleto no cadastro não pode impedir a edição do cliente.
const normalizarTelefones = (dados) => {
    for (const campo of ['telefone_1', 'telefone_2']) {
        if (dados[campo] === undefined) continue;
        const digitos = String(dados[campo] ?? '').replace(/\D/g, '');
        dados[campo] = digitos || null;
    }
};

const criarCliente = async (dadosCliente, usuarioId = null) => {
    const dados = filtrarCamposCliente(dadosCliente);
    await normalizarCpfCnpj(dados);
    await normalizarIdTemporada(dados);
    normalizarCep(dados);
    normalizarTelefones(dados);
    const novoCliente = await prisma.$transaction(async (tx) => {
        const cliente = await tx.clientes.create({ data: dados });
        await logService.registrarAtividade(tx, {
            usuarioId,
            acao: 'criacao',
            entidade: 'cliente',
            entidadeId: cliente.id,
            snapshot: cliente,
        });
        return cliente;
    });
    return novoCliente.id;
};

const listarClientes = async (filtros = {}) => {
    const where = { ativo: true };

    // Pesquisa por nome, CPF/CNPJ, telefone ou "#id" (busca direta pelo id).
    if (filtros.busca) {
        const bruto = filtros.busca.trim();
        if (bruto.startsWith('#')) {
            const idStr = bruto.slice(1);
            where.id = /^\d+$/.test(idStr) ? parseInt(idStr) : -1;
        } else {
            const clausulas = [
                { nome: { contains: bruto } },
                { telefone_1: { contains: bruto } },
            ];
            // cpf_cnpj é armazenado só com dígitos — normaliza o termo de busca
            // antes de comparar, senão um CPF pontuado digitado na busca nunca bate.
            const buscaCpf = limpar(bruto);
            if (buscaCpf) clausulas.push({ cpf_cnpj: { contains: buscaCpf } });
            where.OR = clausulas;
        }
    }

    // Sem busca: retorna só os 20 últimos cadastrados.
    // Com busca: retorna todos os resultados encontrados.
    const clientes = await prisma.clientes.findMany({
        where,
        orderBy: { id: 'desc' },
        take: filtros.busca ? undefined : 20,
    });
    return clientes;
};

// Lista, para a administração, os clientes com ID de Temporada cadastrado,
// em ordem crescente pelo número que vem DEPOIS do hífen (o sequencial do
// cliente) — a temporada em si (antes do hífen) é ignorada na ordenação, a
// pedido do usuário. Sem paginação: é uma conferência completa, não o
// autocomplete de 20 itens do PDV.
const listarClientesPorIdTemporada = async () => {
    const clientes = await prisma.clientes.findMany({
        where: { ativo: true, id_temporada: { not: null } },
    });
    return clientes.sort((a, b) => {
        const sequencialA = parseInt(a.id_temporada.split('-')[1], 10);
        const sequencialB = parseInt(b.id_temporada.split('-')[1], 10);
        return sequencialA - sequencialB;
    });
};

const buscarCliente = async (id) => {
    return await prisma.clientes.findUnique({
        where: { id: parseInt(id), ativo: true }
    });
};

const atualizarCliente = async (id, dadosCliente, usuarioId = null) => {
  const dados = filtrarCamposCliente(dadosCliente);
  await normalizarCpfCnpj(dados, parseInt(id));
  await normalizarIdTemporada(dados, parseInt(id));
  normalizarCep(dados);
  normalizarTelefones(dados);
  return await prisma.$transaction(async (tx) => {
    const cliente = await tx.clientes.update({
      where: { id: parseInt(id) },
      data: dados,
    });
    await logService.registrarAtividade(tx, {
      usuarioId,
      acao: 'atualizacao',
      entidade: 'cliente',
      entidadeId: cliente.id,
      snapshot: cliente,
    });
    return cliente;
  });
};

const eliminarCliente = async (id, usuarioId = null) => {
  return await prisma.$transaction(async (tx) => {
    const cliente = await tx.clientes.update({
      where: { id: parseInt(id) },
      data: {ativo: false}
    });
    await logService.registrarAtividade(tx, {
      usuarioId,
      acao: 'exclusao',
      entidade: 'cliente',
      entidadeId: cliente.id,
      snapshot: cliente,
    });
    return cliente;
  });
};

module.exports = {
    criarCliente,
    listarClientes,
    listarClientesPorIdTemporada,
    buscarCliente,
    atualizarCliente,
    eliminarCliente
};