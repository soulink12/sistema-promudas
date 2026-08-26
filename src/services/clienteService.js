const prisma = require('../config/database');
const BusinessError = require('../utils/BusinessError');
const { limpar, validar } = require('../utils/cpfCnpj');

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

const criarCliente = async (dadosCliente) => {
    const dados = { ...dadosCliente };
    await normalizarCpfCnpj(dados);
    const novoCliente = await prisma.clientes.create({
        data: dados
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

const buscarCliente = async (id) => {
    return await prisma.clientes.findUnique({
        where: { id: parseInt(id) }
    });
};

const atualizarCliente = async (id, dadosCliente) => {
  const dados = { ...dadosCliente };
  await normalizarCpfCnpj(dados, parseInt(id));
  return await prisma.clientes.update({
    where: { id: parseInt(id) },
    data: dados,
  });
};

const eliminarCliente = async (id) => {
  return await prisma.clientes.update({
    where: { id: parseInt(id) },
    data: {ativo: false}
  });
};

module.exports = {
    criarCliente,
    listarClientes,
    buscarCliente,
    atualizarCliente,
    eliminarCliente
};