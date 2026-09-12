-- CreateTable
CREATE TABLE `interessados` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `cliente_id` INTEGER NULL,
    `ativo` BOOLEAN NULL DEFAULT true,
    `observacoes` TEXT NULL,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `interessados_cliente_id_idx`(`cliente_id`),
    INDEX `interessados_criado_em_idx`(`criado_em`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `itens_interesse` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `interessado_id` INTEGER NULL,
    `produto_id` INTEGER NULL,
    `quantidade` INTEGER NOT NULL,

    INDEX `itens_interesse_interessado_id_idx`(`interessado_id`),
    INDEX `itens_interesse_produto_id_idx`(`produto_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `interessados` ADD CONSTRAINT `interessados_cliente_id_fkey` FOREIGN KEY (`cliente_id`) REFERENCES `clientes`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_interesse` ADD CONSTRAINT `itens_interesse_interessado_id_fkey` FOREIGN KEY (`interessado_id`) REFERENCES `interessados`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_interesse` ADD CONSTRAINT `itens_interesse_produto_id_fkey` FOREIGN KEY (`produto_id`) REFERENCES `produtos`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;
