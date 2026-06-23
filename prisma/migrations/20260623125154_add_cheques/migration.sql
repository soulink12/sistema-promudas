-- AlterTable
ALTER TABLE `formas_pagamento` ADD COLUMN `deposito_posterior` BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE `cheques` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `pagamento_id` INTEGER NOT NULL,
    `numero` VARCHAR(50) NULL,
    `banco` VARCHAR(50) NULL,
    `agencia` VARCHAR(20) NULL,
    `conta_corrente` VARCHAR(30) NULL,
    `valor` DECIMAL(10, 2) NOT NULL,
    `bom_para` TIMESTAMP(0) NULL,
    `data_deposito` TIMESTAMP(0) NULL,
    `depositado` BOOLEAN NOT NULL DEFAULT false,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `cheques_pagamento_id_idx`(`pagamento_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `cheques` ADD CONSTRAINT `cheques_pagamento_id_fkey` FOREIGN KEY (`pagamento_id`) REFERENCES `pagamentos`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;
