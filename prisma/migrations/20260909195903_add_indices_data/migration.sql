-- CreateIndex
CREATE INDEX `pedidos_criado_em_idx` ON `pedidos`(`criado_em`);

-- CreateIndex
CREATE INDEX `orcamentos_criado_em_idx` ON `orcamentos`(`criado_em`);

-- CreateIndex
CREATE INDEX `pagamentos_criado_em_idx` ON `pagamentos`(`criado_em`);

-- CreateIndex
CREATE INDEX `pagamentos_data_pagamento_idx` ON `pagamentos`(`data_pagamento`);
