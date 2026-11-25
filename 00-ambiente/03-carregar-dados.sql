-- =============================================================================
-- Tópico : Schema de exemplo — carga de dados
-- Seção  : 00-ambiente
-- Versão : 19c
-- Requer : 02-criar-schema.sql
--
-- Dados fictícios e sem acento de propósito: evita caractere trocado quando o
-- cliente (SQL*Plus no Windows, por exemplo) não está configurado em UTF-8.
--
-- Casos de borda incluídos de propósito, usados nos exemplos:
--   - departamento sem funcionário (50 - Marketing)
--   - funcionário sem departamento (113)
--   - diretoria sem gerente (100) e hierarquia de quatro níveis (100 > 101 > 108 > 104)
--   - pct_comissao nulo para quem não vende
--   - clientes sem pedido (11 e 12), cliente inativo (11), email e limite nulos
--   - produto nunca vendido e inativo (15)
--   - pedido sem vendedor (venda pelo site) e pedido cancelado
--   - preço praticado no item diferente do preço de tabela atual
--   - data_pedido com hora (armadilha do BETWEEN com DATE)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Departamentos
-- -----------------------------------------------------------------------------
INSERT INTO departamentos (id_departamento, nome, cidade) VALUES (10, 'Diretoria',  'Sao Paulo');
INSERT INTO departamentos (id_departamento, nome, cidade) VALUES (20, 'Comercial',  'Sao Paulo');
INSERT INTO departamentos (id_departamento, nome, cidade) VALUES (30, 'Financeiro', 'Belo Horizonte');
INSERT INTO departamentos (id_departamento, nome, cidade) VALUES (40, 'Logistica',  'Goiania');
INSERT INTO departamentos (id_departamento, nome, cidade) VALUES (50, 'Marketing',  NULL);

-- -----------------------------------------------------------------------------
-- Funcionários (inseridos de cima para baixo na hierarquia, por causa da FK
-- de id_gerente)
-- -----------------------------------------------------------------------------
INSERT INTO funcionarios VALUES (100, 'Ana Ribeiro',      'ana.ribeiro@empresa.example',      'Diretor Geral',          25000, NULL, DATE '2015-03-02', NULL, 10);
INSERT INTO funcionarios VALUES (101, 'Bruno Carvalho',   'bruno.carvalho@empresa.example',   'Gerente Comercial',      14000, NULL, DATE '2016-07-11', 100,  20);
INSERT INTO funcionarios VALUES (102, 'Carla Mendes',     'carla.mendes@empresa.example',     'Gerente Financeiro',     13500, NULL, DATE '2017-01-16', 100,  30);
INSERT INTO funcionarios VALUES (103, 'Diego Martins',    'diego.martins@empresa.example',    'Gerente de Logistica',   12000, NULL, DATE '2018-05-07', 100,  40);
INSERT INTO funcionarios VALUES (108, 'Isabela Costa',    'isabela.costa@empresa.example',    'Supervisor de Vendas',    7800,    2, DATE '2017-09-25', 101,  20);
INSERT INTO funcionarios VALUES (104, 'Eduarda Lima',     'eduarda.lima@empresa.example',     'Vendedor',                4800,    5, DATE '2019-02-18', 108,  20);
INSERT INTO funcionarios VALUES (105, 'Felipe Souza',     'felipe.souza@empresa.example',     'Vendedor',                4500,    5, DATE '2020-08-03', 108,  20);
INSERT INTO funcionarios VALUES (106, 'Gabriela Rocha',   'gabriela.rocha@empresa.example',   'Vendedor',                5200,    4, DATE '2018-11-26', 101,  20);
INSERT INTO funcionarios VALUES (107, 'Henrique Alves',   'henrique.alves@empresa.example',   'Vendedor',                4300,    3, DATE '2023-04-10', 108,  20);
INSERT INTO funcionarios VALUES (109, 'Joao Pereira',     'joao.pereira@empresa.example',     'Analista Financeiro',     6200, NULL, DATE '2019-06-17', 102,  30);
INSERT INTO funcionarios VALUES (110, 'Karina Dias',      'karina.dias@empresa.example',      'Assistente Financeiro',   3600, NULL, DATE '2022-03-21', 109,  30);
INSERT INTO funcionarios VALUES (111, 'Lucas Fernandes',  'lucas.fernandes@empresa.example',  'Analista de Logistica',   5400, NULL, DATE '2020-01-13', 103,  40);
INSERT INTO funcionarios VALUES (112, 'Marina Gomes',     'marina.gomes@empresa.example',     'Auxiliar de Logistica',   2900, NULL, DATE '2024-02-05', 111,  40);
INSERT INTO funcionarios VALUES (113, 'Nelson Prado',     'nelson.prado@empresa.example',     'Estagiario',              1800, NULL, DATE '2025-08-04', 101,  NULL);

-- -----------------------------------------------------------------------------
-- Clientes (documentos fictícios, sem dígito verificador válido)
-- -----------------------------------------------------------------------------
INSERT INTO clientes VALUES ( 1, 'Papelaria Central Ltda',     'J', '10000000000101', 'contato@papelariacentral.example', 'Sao Paulo',      'SP', DATE '2021-02-10',  50000, 'S');
INSERT INTO clientes VALUES ( 2, 'Tech Solucoes ME',           'J', '10000000000102', 'compras@techsolucoes.example',     'Campinas',       'SP', DATE '2021-05-22',  30000, 'S');
INSERT INTO clientes VALUES ( 3, 'Escritorio Modelo SA',       'J', '10000000000103', NULL,                               'Belo Horizonte', 'MG', DATE '2022-01-14',  80000, 'S');
INSERT INTO clientes VALUES ( 4, 'Marcos Antonio Silva',       'F', '20000000001',    'marcos.silva@email.example',       'Goiania',        'GO', DATE '2022-03-30',   5000, 'S');
INSERT INTO clientes VALUES ( 5, 'Patricia Moura',             'F', '20000000002',    'patricia.moura@email.example',     'Recife',         'PE', DATE '2022-07-08',   3000, 'S');
INSERT INTO clientes VALUES ( 6, 'Colegio Saber Ltda',         'J', '10000000000104', 'financeiro@colegiosaber.example',  'Palmas',         'TO', DATE '2022-09-19',  40000, 'S');
INSERT INTO clientes VALUES ( 7, 'Rafael Teixeira',            'F', '20000000003',    NULL,                               'Curitiba',       'PR', DATE '2023-01-25',   NULL, 'S');
INSERT INTO clientes VALUES ( 8, 'Clinica Bem Estar Ltda',     'J', '10000000000105', 'adm@bemestar.example',             'Salvador',       'BA', DATE '2023-04-12',  25000, 'S');
INSERT INTO clientes VALUES ( 9, 'Fernanda Araujo',            'F', '20000000004',    'fernanda.araujo@email.example',    'Sao Paulo',      'SP', DATE '2023-08-03',   4000, 'S');
INSERT INTO clientes VALUES (10, 'Construtora Horizonte Ltda', 'J', '10000000000106', 'compras@horizonte.example',        'Brasilia',       'DF', DATE '2024-02-27', 100000, 'S');
INSERT INTO clientes VALUES (11, 'Loja Antiga ME',             'J', '10000000000107', NULL,                               'Fortaleza',      'CE', DATE '2020-06-15',  10000, 'N');
INSERT INTO clientes VALUES (12, 'Thiago Nunes',               'F', '20000000005',    'thiago.nunes@email.example',       'Porto Alegre',   'RS', DATE '2025-10-01',   2000, 'S');

-- -----------------------------------------------------------------------------
-- Categorias (árvore de três níveis)
--   Informatica > Perifericos, Armazenamento
--   Escritorio  > Papelaria, Moveis > Cadeiras
-- -----------------------------------------------------------------------------
INSERT INTO categorias VALUES (1, 'Informatica',   NULL);
INSERT INTO categorias VALUES (2, 'Perifericos',   1);
INSERT INTO categorias VALUES (3, 'Armazenamento', 1);
INSERT INTO categorias VALUES (4, 'Escritorio',    NULL);
INSERT INTO categorias VALUES (5, 'Papelaria',     4);
INSERT INTO categorias VALUES (6, 'Moveis',        4);
INSERT INTO categorias VALUES (7, 'Cadeiras',      6);

-- -----------------------------------------------------------------------------
-- Produtos (preço de tabela atual)
-- -----------------------------------------------------------------------------
INSERT INTO produtos VALUES ( 1, 'Mouse optico USB',               2, 'UN',   39.90, 'S');
INSERT INTO produtos VALUES ( 2, 'Teclado ABNT2',                  2, 'UN',   89.90, 'S');
INSERT INTO produtos VALUES ( 3, 'Monitor 24 polegadas',           2, 'UN',  899.00, 'S');
INSERT INTO produtos VALUES ( 4, 'Webcam Full HD',                 2, 'UN',  249.90, 'S');
INSERT INTO produtos VALUES ( 5, 'SSD 480 GB',                     3, 'UN',  229.90, 'S');
INSERT INTO produtos VALUES ( 6, 'Pen drive 64 GB',                3, 'UN',   49.90, 'S');
INSERT INTO produtos VALUES ( 7, 'HD externo 1 TB',                3, 'UN',  379.00, 'S');
INSERT INTO produtos VALUES ( 8, 'Papel A4 500 folhas',            5, 'PCT',  32.50, 'S');
INSERT INTO produtos VALUES ( 9, 'Caneta esferografica azul cx50', 5, 'CX',   45.00, 'S');
INSERT INTO produtos VALUES (10, 'Grampeador 26/6',                5, 'UN',   27.80, 'S');
INSERT INTO produtos VALUES (11, 'Mesa de escritorio 1,20 m',      6, 'UN',  649.00, 'S');
INSERT INTO produtos VALUES (12, 'Armario 2 portas',               6, 'UN',  899.90, 'S');
INSERT INTO produtos VALUES (13, 'Cadeira giratoria',              7, 'UN',  789.00, 'S');
INSERT INTO produtos VALUES (14, 'Cadeira fixa',                   7, 'UN',  289.00, 'S');
INSERT INTO produtos VALUES (15, 'Hub USB 4 portas',               2, 'UN',   79.90, 'N');

-- -----------------------------------------------------------------------------
-- Pedidos (data com hora)
-- -----------------------------------------------------------------------------
INSERT INTO pedidos VALUES (1001,  1, 104, TO_DATE('2025-01-08 09:15', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1002,  3, 106, TO_DATE('2025-01-15 14:40', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  'Entregar no 3o andar');
INSERT INTO pedidos VALUES (1003,  2, 105, TO_DATE('2025-02-03 10:05', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1004,  6, 104, TO_DATE('2025-02-20 16:30', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1005,  4, NULL, TO_DATE('2025-03-11 21:12', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE', 'Pedido feito pelo site');
INSERT INTO pedidos VALUES (1006,  1, 104, TO_DATE('2025-03-28 11:00', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1007,  8, 106, TO_DATE('2025-04-14 15:25', 'YYYY-MM-DD HH24:MI'), 'CANCELADO', 'Cliente desistiu');
INSERT INTO pedidos VALUES (1008, 10, 108, TO_DATE('2025-05-06 08:50', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1009,  3, 106, TO_DATE('2025-05-30 17:45', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1010,  5, 105, TO_DATE('2025-06-17 13:20', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1011,  2, 105, TO_DATE('2025-07-09 10:30', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1012,  9, NULL, TO_DATE('2025-08-21 22:05', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE', 'Pedido feito pelo site');
INSERT INTO pedidos VALUES (1013,  6, 104, TO_DATE('2025-09-02 09:40', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1014, 10, 108, TO_DATE('2025-10-15 14:10', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1015,  1, 107, TO_DATE('2025-11-04 11:35', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1016,  7, 107, TO_DATE('2025-12-12 16:55', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1017,  3, 106, TO_DATE('2026-01-20 10:15', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1018,  8, 106, TO_DATE('2026-02-24 15:00', 'YYYY-MM-DD HH24:MI'), 'ENTREGUE',  NULL);
INSERT INTO pedidos VALUES (1019,  4, 105, TO_DATE('2026-04-07 09:05', 'YYYY-MM-DD HH24:MI'), 'FATURADO',  NULL);
INSERT INTO pedidos VALUES (1020, 10, 108, TO_DATE('2026-06-18 14:45', 'YYYY-MM-DD HH24:MI'), 'FATURADO',  'Entrega em duas etapas');
INSERT INTO pedidos VALUES (1021,  2, 104, TO_DATE('2026-08-05 11:20', 'YYYY-MM-DD HH24:MI'), 'FATURADO',  NULL);
INSERT INTO pedidos VALUES (1022,  1, 104, TO_DATE('2026-09-29 16:10', 'YYYY-MM-DD HH24:MI'), 'ABERTO',    NULL);
INSERT INTO pedidos VALUES (1023,  9, 107, TO_DATE('2026-10-14 10:50', 'YYYY-MM-DD HH24:MI'), 'ABERTO',    NULL);
INSERT INTO pedidos VALUES (1024,  6, NULL, TO_DATE('2026-10-30 20:30', 'YYYY-MM-DD HH24:MI'), 'ABERTO',   'Pedido feito pelo site');

-- -----------------------------------------------------------------------------
-- Itens dos pedidos
-- Colunas: id_pedido, nr_item, id_produto, quantidade, preco_unitario, pct_desconto
-- -----------------------------------------------------------------------------
INSERT INTO itens_pedido VALUES (1001, 1,  8, 20,  29.90,  0);
INSERT INTO itens_pedido VALUES (1001, 2,  9,  5,  42.00,  0);
INSERT INTO itens_pedido VALUES (1001, 3, 10, 10,  25.00,  5);

INSERT INTO itens_pedido VALUES (1002, 1, 13, 12, 749.00, 10);
INSERT INTO itens_pedido VALUES (1002, 2, 11,  6, 620.00, 10);
INSERT INTO itens_pedido VALUES (1002, 3,  3,  6, 849.00,  5);

INSERT INTO itens_pedido VALUES (1003, 1,  1, 15,  35.90,  0);
INSERT INTO itens_pedido VALUES (1003, 2,  2, 15,  84.90,  0);
INSERT INTO itens_pedido VALUES (1003, 3,  5, 10, 219.90,  3);

INSERT INTO itens_pedido VALUES (1004, 1,  8, 50,  29.90,  8);
INSERT INTO itens_pedido VALUES (1004, 2,  9, 10,  42.00,  8);

INSERT INTO itens_pedido VALUES (1005, 1,  6,  2,  49.90,  0);
INSERT INTO itens_pedido VALUES (1005, 2,  1,  1,  39.90,  0);

INSERT INTO itens_pedido VALUES (1006, 1,  8, 30,  31.00,  0);
INSERT INTO itens_pedido VALUES (1006, 2, 14,  4, 279.00,  0);

INSERT INTO itens_pedido VALUES (1007, 1,  3,  2, 899.00,  0);

INSERT INTO itens_pedido VALUES (1008, 1, 13, 25, 760.00, 12);
INSERT INTO itens_pedido VALUES (1008, 2, 11, 10, 630.00, 12);
INSERT INTO itens_pedido VALUES (1008, 3, 12,  5, 870.00, 10);
INSERT INTO itens_pedido VALUES (1008, 4,  7,  3, 369.00,  0);

INSERT INTO itens_pedido VALUES (1009, 1,  4,  8, 239.90,  5);
INSERT INTO itens_pedido VALUES (1009, 2,  3,  4, 879.00,  5);

INSERT INTO itens_pedido VALUES (1010, 1,  7,  1, 379.00,  0);

INSERT INTO itens_pedido VALUES (1011, 1,  5, 20, 225.00,  5);
INSERT INTO itens_pedido VALUES (1011, 2,  6, 30,  47.90,  5);
INSERT INTO itens_pedido VALUES (1011, 3,  1, 10,  37.90,  0);

INSERT INTO itens_pedido VALUES (1012, 1,  2,  1,  89.90,  0);
INSERT INTO itens_pedido VALUES (1012, 2,  1,  1,  39.90,  0);
INSERT INTO itens_pedido VALUES (1012, 3,  4,  1, 249.90,  0);

INSERT INTO itens_pedido VALUES (1013, 1,  8, 60,  31.50,  8);
INSERT INTO itens_pedido VALUES (1013, 2,  9, 12,  44.00,  8);
INSERT INTO itens_pedido VALUES (1013, 3, 10, 15,  27.00,  5);

INSERT INTO itens_pedido VALUES (1014, 1, 14, 30, 285.00, 10);
INSERT INTO itens_pedido VALUES (1014, 2,  3, 10, 889.00,  7);

INSERT INTO itens_pedido VALUES (1015, 1,  8, 25,  32.50,  0);
INSERT INTO itens_pedido VALUES (1015, 2,  6, 10,  49.90,  0);

INSERT INTO itens_pedido VALUES (1016, 1,  3,  1, 899.00,  0);
INSERT INTO itens_pedido VALUES (1016, 2,  2,  1,  89.90,  0);

INSERT INTO itens_pedido VALUES (1017, 1, 13,  8, 789.00,  8);
INSERT INTO itens_pedido VALUES (1017, 2,  5,  8, 229.90,  5);

INSERT INTO itens_pedido VALUES (1018, 1,  4,  3, 249.90,  0);
INSERT INTO itens_pedido VALUES (1018, 2,  7,  2, 379.00,  0);

INSERT INTO itens_pedido VALUES (1019, 1,  1,  2,  39.90,  0);
INSERT INTO itens_pedido VALUES (1019, 2,  2,  1,  89.90,  0);

INSERT INTO itens_pedido VALUES (1020, 1, 12,  8, 899.90, 10);
INSERT INTO itens_pedido VALUES (1020, 2, 11,  8, 649.00, 10);
INSERT INTO itens_pedido VALUES (1020, 3, 13,  8, 789.00, 10);

INSERT INTO itens_pedido VALUES (1021, 1,  5, 15, 229.90,  4);
INSERT INTO itens_pedido VALUES (1021, 2,  1, 20,  39.90,  4);

INSERT INTO itens_pedido VALUES (1022, 1,  8, 40,  32.50,  5);
INSERT INTO itens_pedido VALUES (1022, 2, 10, 10,  27.80,  0);

INSERT INTO itens_pedido VALUES (1023, 1,  3,  1, 899.00,  0);

INSERT INTO itens_pedido VALUES (1024, 1,  8, 80,  32.50, 10);
INSERT INTO itens_pedido VALUES (1024, 2,  9, 20,  45.00, 10);

COMMIT;
