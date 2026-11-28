-- =============================================================================
-- Tópico : Tabelas e colunas — USER_TABLES, USER_TAB_COLUMNS, comentários
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado
-- =============================================================================

COLUMN table_name  FORMAT A14
COLUMN column_name FORMAT A16
COLUMN tipo        FORMAT A16
COLUMN comments    FORMAT A60 WORD_WRAPPED

-- 1. Tabelas, antes e depois da coleta de estatísticas.
-- Esperado: 7 linhas; num_rows e last_analyzed podem estar vazios
SELECT table_name, num_rows, last_analyzed FROM user_tables ORDER BY table_name;

EXEC DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER)

-- Esperado: CATEGORIAS 7 | CLIENTES 12 | DEPARTAMENTOS 5 | FUNCIONARIOS 14 |
--           ITENS_PEDIDO 54 | PEDIDOS 24 | PRODUTOS 15
SELECT table_name, num_rows, blocks, avg_row_len, last_analyzed
  FROM user_tables
 ORDER BY table_name;

-- 2. Colunas por tabela.
-- Esperado: CATEGORIAS 3 | CLIENTES 10 | DEPARTAMENTOS 3 | FUNCIONARIOS 9 |
--           ITENS_PEDIDO 6 | PEDIDOS 6 | PRODUTOS 6 (total 43)
SELECT c.table_name, COUNT(*) AS colunas
  FROM user_tab_columns c
  JOIN user_tables t ON t.table_name = c.table_name
 GROUP BY c.table_name
 ORDER BY c.table_name;

-- 3. "DESCRIBE" em forma de consulta, com o tipo montado.
-- Esperado (CLIENTES):
--   1 ID_CLIENTE     NUMBER(6)      N
--   2 NOME           VARCHAR2(100)  N
--   3 TIPO_PESSOA    CHAR(1)        N
--   4 DOCUMENTO      VARCHAR2(14)   N
--   5 EMAIL          VARCHAR2(120)  S
--   6 CIDADE         VARCHAR2(60)   N
--   7 UF             CHAR(2)        N
--   8 DATA_CADASTRO  DATE           N   default SYSDATE
--   9 LIMITE_CREDITO NUMBER(12,2)   S
--  10 ATIVO          CHAR(1)        N   default 'S'
SELECT column_id,
       column_name,
       CASE
           WHEN data_type = 'NUMBER' AND data_precision IS NULL AND data_scale = 0 THEN 'INTEGER'
           WHEN data_type = 'NUMBER' AND data_precision IS NULL THEN 'NUMBER'
           WHEN data_type = 'NUMBER' AND data_scale = 0 THEN 'NUMBER(' || data_precision || ')'
           WHEN data_type = 'NUMBER' THEN 'NUMBER(' || data_precision || ',' || data_scale || ')'
           WHEN data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR')
               THEN data_type || '(' || char_length || CASE WHEN char_used = 'C' THEN ' CHAR' END || ')'
           ELSE data_type
       END AS tipo,
       DECODE(nullable, 'Y', 'S', 'N') AS aceita_nulo,
       data_default
  FROM user_tab_columns
 WHERE table_name = 'CLIENTES'
 ORDER BY column_id;

-- 4. Perfil do schema: tipos usados e colunas que aceitam NULL.
-- Esperado: NUMBER 22 | VARCHAR2 14 | CHAR 4 | DATE 3
SELECT c.data_type, COUNT(*) AS colunas
  FROM user_tab_columns c
  JOIN user_tables t ON t.table_name = c.table_name
 GROUP BY c.data_type
 ORDER BY colunas DESC;

-- Esperado: 9 colunas
--   CATEGORIAS.ID_CATEGORIA_PAI, CLIENTES.EMAIL, CLIENTES.LIMITE_CREDITO,
--   DEPARTAMENTOS.CIDADE, FUNCIONARIOS.ID_DEPARTAMENTO, FUNCIONARIOS.ID_GERENTE,
--   FUNCIONARIOS.PCT_COMISSAO, PEDIDOS.ID_VENDEDOR, PEDIDOS.OBSERVACAO
SELECT c.table_name || '.' || c.column_name AS coluna_que_aceita_nulo
  FROM user_tab_columns c
  JOIN user_tables t ON t.table_name = c.table_name
 WHERE c.nullable = 'Y'
 ORDER BY 1;

-- 5. Onde está a coluna X?
-- Esperado: CLIENTES | PEDIDOS
SELECT table_name FROM user_tab_columns WHERE column_name = 'ID_CLIENTE' ORDER BY table_name;

-- Busca aproximada: qualquer coluna com "PRECO" no nome.
-- Esperado: ITENS_PEDIDO.PRECO_UNITARIO | PRODUTOS.PRECO_UNITARIO
SELECT table_name || '.' || column_name AS coluna
  FROM user_tab_columns
 WHERE column_name LIKE '%PRECO%'
 ORDER BY 1;

-- 6. Mesmo nome de coluna em tabelas diferentes: candidatas a junção.
-- Esperado:
--   ATIVO           2 CLIENTES, PRODUTOS
--   CIDADE          2 CLIENTES, DEPARTAMENTOS
--   EMAIL           2 CLIENTES, FUNCIONARIOS
--   ID_CATEGORIA    2 CATEGORIAS, PRODUTOS
--   ID_CLIENTE      2 CLIENTES, PEDIDOS
--   ID_DEPARTAMENTO 2 DEPARTAMENTOS, FUNCIONARIOS
--   ID_PEDIDO       2 ITENS_PEDIDO, PEDIDOS
--   ID_PRODUTO      2 ITENS_PEDIDO, PRODUTOS
--   NOME            5 CATEGORIAS, CLIENTES, DEPARTAMENTOS, FUNCIONARIOS, PRODUTOS
--   PRECO_UNITARIO  2 ITENS_PEDIDO, PRODUTOS
--   (ID_% são junções reais; NOME, CIDADE, ATIVO são só nomes iguais: o dicionário
--    sugere, quem confirma é o conhecimento do negócio ou a FK do tópico 03)
SELECT c.column_name,
       COUNT(*) AS tabelas,
       LISTAGG(c.table_name, ', ') WITHIN GROUP (ORDER BY c.table_name) AS onde
  FROM user_tab_columns c
  JOIN user_tables t ON t.table_name = c.table_name
 GROUP BY c.column_name
HAVING COUNT(*) > 1
 ORDER BY c.column_name;

-- 7. Lista de colunas pronta para usar num SELECT.
-- Esperado: id_pedido, id_cliente, id_vendedor, data_pedido, status, observacao
SELECT LOWER(LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id)) AS colunas
  FROM user_tab_columns
 WHERE table_name = 'PEDIDOS';

-- 8. Comentários.
-- Esperado: 7 tabelas, todas com comentário
SELECT table_name, comments FROM user_tab_comments WHERE table_type = 'TABLE' ORDER BY table_name;

-- Esperado: 6 colunas comentadas, de 43
--   CLIENTES.DOCUMENTO, CLIENTES.LIMITE_CREDITO, FUNCIONARIOS.ID_GERENTE,
--   FUNCIONARIOS.PCT_COMISSAO, ITENS_PEDIDO.PCT_DESCONTO, PEDIDOS.ID_VENDEDOR
SELECT table_name || '.' || column_name AS coluna, comments
  FROM user_col_comments
 WHERE comments IS NOT NULL
 ORDER BY 1;

-- Colunas sem comentário, por tabela: o que falta documentar.
-- Esperado: CATEGORIAS 3 | CLIENTES 8 | DEPARTAMENTOS 3 | FUNCIONARIOS 7 |
--           ITENS_PEDIDO 5 | PEDIDOS 5 | PRODUTOS 6
SELECT cc.table_name, COUNT(*) AS sem_comentario
  FROM user_col_comments cc
  JOIN user_tables t ON t.table_name = cc.table_name
 WHERE cc.comments IS NULL
 GROUP BY cc.table_name
 ORDER BY cc.table_name;

-- 9. Colunas ocultas e virtuais: USER_TAB_COLS mostra, USER_TAB_COLUMNS não.
CREATE TABLE tmp_virtual (
    preco      NUMBER(10,2),
    quantidade NUMBER(10,3),
    total      AS (ROUND(preco * quantidade, 2)) VIRTUAL
);

-- Esperado: PRECO NO NO | QUANTIDADE NO NO | TOTAL YES NO
SELECT column_name, virtual_column, hidden_column
  FROM user_tab_cols
 WHERE table_name = 'TMP_VIRTUAL'
 ORDER BY column_id;

DROP TABLE tmp_virtual PURGE;
