-- Converte as colunas de data para timestamp com hora, preservando os valores existentes.
-- MODIFY (em vez de DROP + ADD) mantém os dados: valores DATE viram TIMESTAMP à meia-noite.

-- AlterTable
ALTER TABLE `pedidos` MODIFY `data_pedido` TIMESTAMP(0) NULL;

-- AlterTable
ALTER TABLE `entregas` MODIFY `data_entrega` TIMESTAMP(0) NULL;

-- AlterTable
ALTER TABLE `pagamentos` MODIFY `data_pagamento` TIMESTAMP(0) NULL;
