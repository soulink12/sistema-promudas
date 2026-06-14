-- AlterTable
ALTER TABLE `formas_pagamento` ADD COLUMN `parcelado_em_ate` INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE `pagamentos` ADD COLUMN `parcelas` INTEGER NOT NULL DEFAULT 1;
