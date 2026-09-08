
-- AlterTable
ALTER TABLE `clientes` ADD COLUMN `email` VARCHAR(150) NULL;

-- CreateTable
CREATE TABLE `orcamentos` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `cliente_id` INTEGER NULL,
    `ativo` BOOLEAN NULL DEFAULT true,
    `data_orcamento` TIMESTAMP(0) NULL,
    `valor_total` DECIMAL(10, 2) NULL,
    `ajuste` DECIMAL(10, 2) NULL,
    `status` VARCHAR(20) NULL DEFAULT 'Pendente',
    `observacoes` TEXT NULL,
    `pedido_id` INTEGER NULL,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `orcamentos_cliente_id_idx`(`cliente_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `itens_orcamento` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `orcamento_id` INTEGER NULL,
    `produto_id` INTEGER NULL,
    `quantidade` INTEGER NOT NULL,
    `valor_unitario` DECIMAL(10, 2) NULL,

    INDEX `itens_orcamento_orcamento_id_idx`(`orcamento_id`),
    INDEX `itens_orcamento_produto_id_idx`(`produto_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `orcamentos` ADD CONSTRAINT `orcamentos_cliente_id_fkey` FOREIGN KEY (`cliente_id`) REFERENCES `clientes`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `orcamentos` ADD CONSTRAINT `orcamentos_pedido_id_fkey` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_orcamento` ADD CONSTRAINT `itens_orcamento_orcamento_id_fkey` FOREIGN KEY (`orcamento_id`) REFERENCES `orcamentos`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_orcamento` ADD CONSTRAINT `itens_orcamento_produto_id_fkey` FOREIGN KEY (`produto_id`) REFERENCES `produtos`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

