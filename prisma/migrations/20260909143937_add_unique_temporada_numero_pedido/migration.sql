-- CreateIndex
ALTER TABLE `pedidos` ADD UNIQUE INDEX `pedidos_temporada_ano_numero_temporada_key`(`temporada_ano`, `numero_temporada`);
