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
    `saldo_credito` DECIMAL(10, 2) NULL DEFAULT 0,
    `ativo` BOOLEAN NULL DEFAULT true,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pedidos` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `cliente_id` INTEGER NULL,
    `ativo` BOOLEAN NULL DEFAULT true,
    `data_pedido` DATE NULL,
    `valor_total` DECIMAL(10, 2) NULL,
    `ajuste` DECIMAL(10, 2) NULL,
    `status_geral` VARCHAR(30) NULL DEFAULT 'Ativa',
    `status_pagamento` VARCHAR(30) NULL DEFAULT 'Pendente',
    `status_entrega` VARCHAR(30) NULL DEFAULT 'Pendente',
    `observacoes` TEXT NULL,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `pedidos_cliente_id_idx`(`cliente_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `produtos` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(50) NOT NULL,
    `preco` DECIMAL(10, 2) NOT NULL,
    `ativo` BOOLEAN NULL DEFAULT true,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `itens_pedido` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `pedido_id` INTEGER NULL,
    `produto_id` INTEGER NULL,
    `quantidade` INTEGER NOT NULL,
    `valor_unitario` DECIMAL(10, 2) NULL,

    INDEX `itens_pedido_pedido_id_idx`(`pedido_id`),
    INDEX `itens_pedido_produto_id_idx`(`produto_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `entregas` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `pedido_id` INTEGER NOT NULL,
    `data_entrega` DATE NULL,
    `local_entrega` VARCHAR(50) NULL,
    `motorista` VARCHAR(100) NULL,
    `placa_veiculo` VARCHAR(20) NULL,
    `status_entrega` VARCHAR(30) NULL DEFAULT 'Realizada',
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `entregas_pedido_id_idx`(`pedido_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `itens_entrega` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `entrega_id` INTEGER NOT NULL,
    `produto_id` INTEGER NOT NULL,
    `quantidade` INTEGER NOT NULL,

    INDEX `itens_entrega_entrega_id_idx`(`entrega_id`),
    INDEX `itens_entrega_produto_id_idx`(`produto_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pagamentos` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `pedido_id` INTEGER NULL,
    `valor_pago` DECIMAL(10, 2) NOT NULL,
    `data_pagamento` DATE NULL,
    `forma_pagamento` VARCHAR(50) NULL,
    `conta` VARCHAR(50) NULL,
    `recebedor` VARCHAR(50) NULL,
    `nome_pagador` VARCHAR(100) NULL,
    `cpf_cnpj_pagador` VARCHAR(20) NULL,
    `status_nota` VARCHAR(30) NULL DEFAULT 'Pendente',
    `numero_nota` VARCHAR(50) NULL,
    `data_emissao_nota` DATE NULL,
    `criado_em` TIMESTAMP(0) NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `pagamentos_pedido_id_idx`(`pedido_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `usuarios` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(191) NOT NULL,
    `email` VARCHAR(191) NOT NULL,
    `senha_hash` VARCHAR(191) NOT NULL,
    `ativo` BOOLEAN NOT NULL DEFAULT true,
    `criado_em` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `usuarios_email_key`(`email`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `formas_pagamento` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(50) NOT NULL,
    `ativo` BOOLEAN NOT NULL DEFAULT true,
    `pagamento_posterior` BOOLEAN NOT NULL DEFAULT false,
    `conta_posterior` BOOLEAN NOT NULL DEFAULT false,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `locais_entrega` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(50) NOT NULL,
    `ativo` BOOLEAN NOT NULL DEFAULT true,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `contas` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(50) NOT NULL,
    `ativo` BOOLEAN NOT NULL DEFAULT true,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `pedidos` ADD CONSTRAINT `pedidos_cliente_id_fkey` FOREIGN KEY (`cliente_id`) REFERENCES `clientes`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_pedido` ADD CONSTRAINT `itens_pedido_pedido_id_fkey` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_pedido` ADD CONSTRAINT `itens_pedido_produto_id_fkey` FOREIGN KEY (`produto_id`) REFERENCES `produtos`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `entregas` ADD CONSTRAINT `entregas_pedido_id_fkey` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_entrega` ADD CONSTRAINT `itens_entrega_entrega_id_fkey` FOREIGN KEY (`entrega_id`) REFERENCES `entregas`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `itens_entrega` ADD CONSTRAINT `itens_entrega_produto_id_fkey` FOREIGN KEY (`produto_id`) REFERENCES `produtos`(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `pagamentos` ADD CONSTRAINT `pagamentos_pedido_id_fkey` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;
