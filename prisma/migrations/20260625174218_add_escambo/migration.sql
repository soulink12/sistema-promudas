-- AlterTable
ALTER TABLE `formas_pagamento` ADD COLUMN `escambo` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `valor_kg_escambo` DECIMAL(10, 2) NULL;

-- AlterTable
ALTER TABLE `pagamentos` ADD COLUMN `escambo_quantidade` DECIMAL(10, 2) NULL;
