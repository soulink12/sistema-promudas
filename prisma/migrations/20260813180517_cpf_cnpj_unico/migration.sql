-- Normaliza cpf_cnpj existente para só dígitos antes de criar o índice único
-- (dados legados/seed podem conter pontuação: xxx.xxx.xxx-xx ou xx.xxx.xxx/xxxx-xx).
UPDATE `clientes`
SET `cpf_cnpj` = NULLIF(REGEXP_REPLACE(`cpf_cnpj`, '[^0-9]', ''), '')
WHERE `cpf_cnpj` IS NOT NULL;

-- AlterTable
ALTER TABLE `clientes` ADD UNIQUE INDEX `clientes_cpf_cnpj_key`(`cpf_cnpj`);
