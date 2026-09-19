-- AlterTable
ALTER TABLE `orcamentos` ADD COLUMN `temporada_ano` INTEGER NULL, ADD COLUMN `numero_temporada` INTEGER NULL;

-- CreateIndex
CREATE INDEX `orcamentos_temporada_ano_idx` ON `orcamentos`(`temporada_ano`);

-- CreateIndex
ALTER TABLE `orcamentos` ADD UNIQUE INDEX `orcamentos_temporada_ano_numero_temporada_key`(`temporada_ano`, `numero_temporada`);
