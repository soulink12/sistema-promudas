-- CreateTable
CREATE TABLE `clientes` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `cpf_cnpj` VARCHAR(20) NULL,
    `inscricao_estadual` VARCHAR(30) NULL,
    `nome` VARCHAR(100) NOT NULL,
    `telefone_1` VARCHAR(20) NULL,
    `telefone_2` VARCHAR(20) NULL,
    `cep` VARCHAR(10) NULL,
    `logradouro` VARCHAR(150) NULL,
    `numero` VARCHAR(20) NULL,
    `bairro` VARCHAR(100) NULL,
    `cidade` VARCHAR(100) NULL,
    `estado` VARCHAR(2) NULL DEFAULT 'PA',
    `ativo` BOOLEAN NULL DEFAULT true,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `encomendas` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `cliente_id` INTEGER NULL,
    `data_encomenda` DATE NULL,
    `valor_total` DECIMAL(10, 2) NULL,
    `status_geral` VARCHAR(30) NULL DEFAULT 'Ativa',
    `status_pagamento` VARCHAR(30) NULL DEFAULT 'Pendente',
    `status_entrega` VARCHAR(30) NULL DEFAULT 'Pendente',
    `observacoes` TEXT NULL,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `cliente_id`(`cliente_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `entregas` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `encomenda_id` INTEGER NOT NULL,
    `data_entrega` DATE NULL,
    `local_saida` VARCHAR(50) NULL,
    `motorista` VARCHAR(100) NULL,
    `placa_veiculo` VARCHAR(20) NULL,
    `status_entrega` VARCHAR(30) NULL DEFAULT 'Realizada',
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `encomenda_id`(`encomenda_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `itens_encomenda` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `encomenda_id` INTEGER NULL,
    `variedade_id` INTEGER NULL,
    `quantidade` INTEGER NOT NULL,
    `valor_unitario` DECIMAL(10, 2) NULL,

    INDEX `encomenda_id`(`encomenda_id`),
    INDEX `variedade_id`(`variedade_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `itens_entrega` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `entrega_id` INTEGER NOT NULL,
    `variedade_id` INTEGER NOT NULL,
    `quantidade` INTEGER NOT NULL,

    INDEX `entrega_id`(`entrega_id`),
    INDEX `variedade_id`(`variedade_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pagamentos` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `encomenda_id` INTEGER NULL,
    `valor_pago` DECIMAL(10, 2) NOT NULL,
    `data_pagamento` DATE NULL,
    `forma_pagamento` VARCHAR(50) NULL,
    `recebedor` VARCHAR(50) NULL,
    `nome_pagador` VARCHAR(100) NULL,
    `cpf_cnpj_pagador` VARCHAR(20) NULL,
    `status_nota` VARCHAR(30) NULL DEFAULT 'Pendente',
    `numero_nota` VARCHAR(50) NULL,
    `data_emissao_nota` DATE NULL,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `encomenda_id`(`encomenda_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `variedades` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(50) NOT NULL,
    `ativo` BOOLEAN NULL DEFAULT true,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `encomendas` ADD CONSTRAINT `encomendas_ibfk_1` FOREIGN KEY (`cliente_id`) REFERENCES `clientes`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `entregas` ADD CONSTRAINT `entregas_ibfk_1` FOREIGN KEY (`encomenda_id`) REFERENCES `encomendas`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_encomenda` ADD CONSTRAINT `itens_encomenda_ibfk_1` FOREIGN KEY (`encomenda_id`) REFERENCES `encomendas`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_encomenda` ADD CONSTRAINT `itens_encomenda_ibfk_2` FOREIGN KEY (`variedade_id`) REFERENCES `variedades`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_entrega` ADD CONSTRAINT `itens_entrega_ibfk_1` FOREIGN KEY (`entrega_id`) REFERENCES `entregas`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_entrega` ADD CONSTRAINT `itens_entrega_ibfk_2` FOREIGN KEY (`variedade_id`) REFERENCES `variedades`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `pagamentos` ADD CONSTRAINT `pagamentos_ibfk_1` FOREIGN KEY (`encomenda_id`) REFERENCES `encomendas`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;
