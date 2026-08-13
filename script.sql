##CREATE DATABASE sistemaPromudas;
SHOW DATABASES;
USE sistemaPromudas;
INSERT INTO formas_pagamento (nome) VALUES ('Dinheiro'), ('Cartão de Crédito'), ('Cartão de Débito'), ('PIX');
show tables;
INSERT INTO produtos (nome, preco, ativo) VALUES
  ('Muda de Açaí BRS',       2.50,  true),
  ('Muda de Cacau Clone',     4.00,  true),
  ('Muda de Cupuaçu',        3.50,  true),
  ('Semente de Andiroba',    1.20,  true),
  ('Muda de Banana Prata',   5.00,  true),
  ('Adubo Orgânico 1kg',    15.00,  true);
  
INSERT INTO clientes (id, nome, cpf_cnpj, telefone_1, cidade, estado)
VALUES (1, 'Consumidor', NULL, NULL, NULL, 'PA');
ALTER TABLE clientes AUTO_INCREMENT = 2;
INSERT INTO clientes (nome, cpf_cnpj, telefone_1, telefone_2, cep, logradouro, numero, bairro, cidade, estado) VALUES
  ('João Silva',        '11111111111', '(91) 99999-1111', NULL,              '66000-000', 'Rua das Flores',     '10',  'Centro',        'Belém',        'PA'),
  ('Maria Oliveira',    '22222222222', '(91) 98888-2222', '(91) 3333-2222',  '66010-000', 'Av. Nazaré',         '250', 'Nazaré',        'Belém',        'PA'),
  ('Carlos Souza',      '33333333333', '(91) 97777-3333', NULL,              '68400-000', 'Trav. dos Ipês',     '5',   'São João',      'Castanhal',    'PA'),
  ('Ana Paula Ferreira','44444444444', '(91) 96666-4444', NULL,              '68005-000', 'Rua Sete de Setembro','88', 'Jaderlândia',   'Castanhal',    'PA'),
  ('Fazenda Boa Terra', '11111111000111', '(91) 3245-5555', '(91) 99111-5555', '68740-000', 'Ramal do Açaí',  's/n', 'Zona Rural',    'Tomé-Açu',     'PA');
  
INSERT INTO formas_pagamento (nome) VALUES ('Crediário');
UPDATE formas_pagamento SET pagamento_posterior = 1 WHERE nome = 'Crediário';
  
  

