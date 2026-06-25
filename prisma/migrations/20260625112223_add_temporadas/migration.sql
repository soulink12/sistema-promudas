-- AlterTable
ALTER TABLE `pedidos` ADD COLUMN `numero_temporada` INTEGER NULL,
    ADD COLUMN `temporada_ano` INTEGER NULL;

-- CreateTable
CREATE TABLE `temporadas` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `ano` INTEGER NOT NULL,
    `ativo` BOOLEAN NOT NULL DEFAULT false,
    `criado_em` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `temporadas_ano_key`(`ano`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `pedidos_temporada_ano_idx` ON `pedidos`(`temporada_ano`);
