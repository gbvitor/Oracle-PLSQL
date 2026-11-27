-- =============================================================================
-- Tópico : Views — criação, CHECK OPTION, READ ONLY, invalidação
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE VIEW
-- =============================================================================

-- 1. View de vendas: valor líquido por item, com cliente, vendedor e produto.
CREATE OR REPLACE VIEW tmp_vw_vendas AS
SELECT p.id_pedido,
       p.data_pedido,
       p.status,
       c.id_cliente,
       c.nome                          AS cliente,
       c.uf,
       NVL(f.nome, 'site')             AS vendedor,
       pr.nome                         AS produto,
       i.quantidade,
       ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2) AS valor_liquido
  FROM pedidos      p
  JOIN clientes     c  ON c.id_cliente   = p.id_cliente
  LEFT JOIN funcionarios f ON f.id_funcionario = p.id_vendedor
  JOIN itens_pedido i  ON i.id_pedido    = p.id_pedido
  JOIN produtos     pr ON pr.id_produto  = i.id_produto;

-- Consultar a view como uma tabela.
-- Esperado: SP 3 clientes; total sem cancelados 121017.43
SELECT uf, COUNT(DISTINCT id_cliente) AS clientes, SUM(valor_liquido) AS total
  FROM tmp_vw_vendas
 WHERE status <> 'CANCELADO'
 GROUP BY ROLLUP(uf)
 ORDER BY uf NULLS LAST;

-- 2. View com agregação não aceita DML.
CREATE OR REPLACE VIEW tmp_vw_total_cliente AS
SELECT id_cliente, SUM(valor_liquido) AS total
  FROM tmp_vw_vendas
 WHERE status <> 'CANCELADO'
 GROUP BY id_cliente;

-- Esperado: ORA-01732 (operação de manipulação de dados não válida nesta view)
UPDATE tmp_vw_total_cliente SET total = 0 WHERE id_cliente = 1;

-- 3. View de filtro com WITH CHECK OPTION.
CREATE OR REPLACE VIEW tmp_vw_clientes_sp AS
SELECT id_cliente, nome, cidade, uf
  FROM clientes
 WHERE uf = 'SP'
  WITH CHECK OPTION;

-- Alteração que mantém a linha na view: aceita.
-- Esperado: 1 linha atualizada
UPDATE tmp_vw_clientes_sp SET cidade = 'Santos' WHERE id_cliente = 2;

-- Alteração que tiraria a linha da view: recusada.
-- Esperado: ORA-01402 (violação da cláusula WHERE da view WITH CHECK OPTION)
UPDATE tmp_vw_clientes_sp SET uf = 'MG' WHERE id_cliente = 2;

ROLLBACK;

-- 4. WITH READ ONLY.
CREATE OR REPLACE VIEW tmp_vw_produtos_ativos AS
SELECT id_produto, nome, preco_unitario FROM produtos WHERE ativo = 'S'
  WITH READ ONLY;

-- Esperado: ORA-42399 (não é possível executar uma operação DML em uma view somente para leitura)
UPDATE tmp_vw_produtos_ativos SET preco_unitario = 0 WHERE id_produto = 1;

-- 5. SELECT * fixa as colunas na criação; remover coluna invalida a view.
CREATE TABLE tmp_base (a NUMBER, b NUMBER);
INSERT INTO tmp_base VALUES (1, 2);
COMMIT;

CREATE OR REPLACE VIEW tmp_vw_base AS SELECT * FROM tmp_base;

ALTER TABLE tmp_base ADD (c NUMBER DEFAULT 3);

-- Esperado: só A e B (a coluna C nova não aparece)
SELECT * FROM tmp_vw_base;

ALTER TABLE tmp_base DROP COLUMN b;

-- Esperado: INVALID
SELECT object_name, status FROM user_objects WHERE object_name = 'TMP_VW_BASE';

-- Esperado: ORA-04063 (view possui erros)
SELECT * FROM tmp_vw_base;

-- 6. Definição das views no dicionário (texto da consulta).
SELECT view_name, text_length
  FROM user_views
 WHERE view_name LIKE 'TMP_VW%'
 ORDER BY view_name;

-- Limpeza
DROP VIEW tmp_vw_base;
DROP TABLE tmp_base PURGE;
DROP VIEW tmp_vw_produtos_ativos;
DROP VIEW tmp_vw_clientes_sp;
DROP VIEW tmp_vw_total_cliente;
DROP VIEW tmp_vw_vendas;
