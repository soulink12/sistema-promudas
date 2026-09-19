-- DropForeignKey
ALTER TABLE `itens_interesse` DROP FOREIGN KEY `itens_interesse_interessado_id_fkey`;

-- DropForeignKey
ALTER TABLE `itens_interesse` DROP FOREIGN KEY `itens_interesse_produto_id_fkey`;

-- DropForeignKey
ALTER TABLE `interessados` DROP FOREIGN KEY `interessados_cliente_id_fkey`;

-- DropTable
DROP TABLE `itens_interesse`;

-- DropTable
DROP TABLE `interessados`;
