-- CreateTable
CREATE TABLE `logs_atividade` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `usuario_id` INTEGER NULL,
    `acao` VARCHAR(30) NOT NULL,
    `entidade` VARCHAR(30) NOT NULL,
    `entidade_id` INTEGER NULL,
    `snapshot` JSON NULL,
    `criado_em` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `logs_atividade_entidade_entidade_id_idx`(`entidade`, `entidade_id`),
    INDEX `logs_atividade_criado_em_idx`(`criado_em`),
    INDEX `logs_atividade_usuario_id_idx`(`usuario_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `logs_erro` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `usuario_id` INTEGER NULL,
    `origem` VARCHAR(20) NOT NULL,
    `mensagem` TEXT NOT NULL,
    `stack` TEXT NULL,
    `rota` VARCHAR(255) NULL,
    `metodo_http` VARCHAR(10) NULL,
    `status_code` INTEGER NULL,
    `criado_em` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `logs_erro_criado_em_idx`(`criado_em`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `logs_atividade` ADD CONSTRAINT `logs_atividade_usuario_id_fkey` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `logs_erro` ADD CONSTRAINT `logs_erro_usuario_id_fkey` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;
