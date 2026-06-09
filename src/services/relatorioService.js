const prisma = require('../config/database');

const relatorioPagamentos = async ({ de, ate, forma }) => {
    // TODO: quando data_pagamento se tornar obrigatório, remover o OR e filtrar só por data_pagamento
    const whereData = (de || ate) ? {
        OR: [
            {
                data_pagamento: {
                    ...(de && { gte: new Date(de) }),
                    ...(ate && { lte: new Date(ate) }),
                }
            },
            {
                data_pagamento: null,
                criado_em: {
                    ...(de && { gte: new Date(de) }),
                    ...(ate && { lte: new Date(ate) }),
                }
            }
        ]
    } : {};

    const where = {
        ...whereData,
        ...(forma ? { forma_pagamento: forma } : {})
    };

    const grupos = await prisma.pagamentos.groupBy({
        by: ['forma_pagamento'],
        where,
        _sum: { valor_pago: true },
        _count: { id: true },
        orderBy: { _sum: { valor_pago: 'desc' } }
    });

    const resultado = grupos.map(g => ({
        forma_pagamento: g.forma_pagamento ?? '(não informado)',
        total: parseFloat(g._sum.valor_pago ?? 0),
        quantidade: g._count.id,
    }));

    const totalGeral = resultado.reduce((soma, r) => soma + r.total, 0);

    return { resultado, totalGeral };
};

module.exports = { relatorioPagamentos };
