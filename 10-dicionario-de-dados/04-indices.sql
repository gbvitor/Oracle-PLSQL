-- =============================================================================
-- Tópico : Índices — USER_INDEXES, USER_IND_COLUMNS, USER_IND_EXPRESSIONS,
--          estatísticas, redundância e tamanho
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado
-- =============================================================================

COLUMN index_name  FORMAT A26
COLUMN table_name  FORMAT A14
COLUMN colunas     FORMAT A26
COLUMN expressao   FORMAT A30

-- Estatísticas atualizadas para os passos 3 e 4.
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER)

-- 1. Índices por tabela.
-- Esperado: CATEGORIAS 2 | CLIENTES 2 | DEPARTAMENTOS 2 | FUNCIONARIOS 4 |
--           ITENS_PEDIDO 2 | PEDIDOS 4 | PRODUTOS 2 (total 18; 10 UNIQUE, 8 NONUNIQUE)
SELECT table_name,
       COUNT(*) AS indices,
       SUM(CASE WHEN uniqueness = 'UNIQUE' THEN 1 ELSE 0 END) AS unicos
  FROM user_indexes
 GROUP BY table_name
 ORDER BY table_name;

-- 2. Cada índice com suas colunas, na ordem.
-- Esperado: 18 linhas; PK_ITENS_PEDIDO com "ID_PEDIDO, NR_ITEM"
SELECT i.table_name,
       i.index_name,
       i.uniqueness,
       LISTAGG(ic.column_name, ', ') WITHIN GROUP (ORDER BY ic.column_position) AS colunas
  FROM user_indexes i
  JOIN user_ind_columns ic ON ic.index_name = i.index_name
 GROUP BY i.table_name, i.index_name, i.uniqueness
 ORDER BY i.table_name, i.index_name;

-- 3. Linhas com a coluna NULL não entram no índice B-tree.
-- Esperado:
--   PK_CLIENTES              num_rows 12  distinct_keys 12
--   IX_FUNCIONARIOS_DEPTO    num_rows 13  distinct_keys 4   (tabela 14: um sem departamento)
--   IX_FUNCIONARIOS_GERENTE  num_rows 13  distinct_keys 7   (tabela 14: a diretoria não tem gerente)
--   IX_PEDIDOS_VENDEDOR      num_rows 21  distinct_keys 5   (tabela 24: 3 pedidos do site, sem vendedor)
--   IX_PEDIDOS_CLIENTE       num_rows 24  distinct_keys 10
SELECT i.index_name, i.num_rows, i.distinct_keys, t.num_rows AS linhas_tabela
  FROM user_indexes i
  JOIN user_tables t ON t.table_name = i.table_name
 WHERE i.index_name IN ('IX_FUNCIONARIOS_DEPTO', 'IX_FUNCIONARIOS_GERENTE',
                        'IX_PEDIDOS_VENDEDOR', 'IX_PEDIDOS_CLIENTE', 'PK_CLIENTES')
 ORDER BY i.num_rows, i.index_name;

-- 4. Altura e clustering factor.
-- Esperado: BLEVEL 0 em todos (tabelas pequenas cabem numa folha);
--           clustering_factor entre o número de blocos e o de linhas da tabela
SELECT i.index_name, i.blevel, i.leaf_blocks, i.clustering_factor, t.blocks, t.num_rows
  FROM user_indexes i
  JOIN user_tables t ON t.table_name = i.table_name
 WHERE i.table_name = 'PEDIDOS'
 ORDER BY i.index_name;

-- 5. Índice baseado em função: a expressão fica em USER_IND_EXPRESSIONS.
CREATE TABLE tmp_clientes AS SELECT * FROM clientes;
CREATE INDEX tmp_ix_clientes_nome_upper ON tmp_clientes (UPPER(nome));

-- Esperado: coluna com nome gerado (SYS_NC...$) em USER_IND_COLUMNS
SELECT index_name, column_name FROM user_ind_columns WHERE index_name = 'TMP_IX_CLIENTES_NOME_UPPER';

-- Esperado: UPPER("NOME") e index_type FUNCTION-BASED NORMAL
SELECT e.index_name, e.column_expression AS expressao, i.index_type
  FROM user_ind_expressions e
  JOIN user_indexes i ON i.index_name = e.index_name
 WHERE e.index_name = 'TMP_IX_CLIENTES_NOME_UPPER';

-- 6. Índice redundante: colunas que são prefixo de outro índice da mesma tabela.
CREATE INDEX tmp_ix_clientes_uf_cidade ON tmp_clientes (uf, cidade);
CREATE INDEX tmp_ix_clientes_uf        ON tmp_clientes (uf);

-- Esperado: TMP_IX_CLIENTES_UF (UF) coberto por TMP_IX_CLIENTES_UF_CIDADE (UF, CIDADE)
WITH ind AS (
    SELECT i.table_name,
           i.index_name,
           i.uniqueness,
           LISTAGG(ic.column_name, ',') WITHIN GROUP (ORDER BY ic.column_position) AS cols
      FROM user_indexes i
      JOIN user_ind_columns ic ON ic.index_name = i.index_name
     GROUP BY i.table_name, i.index_name, i.uniqueness
)
SELECT r.index_name AS redundante,
       r.cols       AS colunas_redundante,
       c.index_name AS coberto_por,
       c.cols       AS colunas_cobertura
  FROM ind r
  JOIN ind c
    ON c.table_name = r.table_name
   AND c.index_name <> r.index_name
   AND c.cols LIKE r.cols || ',%'
 WHERE r.uniqueness = 'NONUNIQUE'
 ORDER BY r.table_name, r.index_name;

-- 7. Índices inutilizáveis depois de mover a tabela.
ALTER TABLE tmp_clientes MOVE;

-- Esperado: os três TMP_IX_... com STATUS UNUSABLE
SELECT index_name, status FROM user_indexes WHERE table_name = 'TMP_CLIENTES' ORDER BY index_name;

ALTER INDEX tmp_ix_clientes_uf_cidade  REBUILD;
ALTER INDEX tmp_ix_clientes_uf         REBUILD;
ALTER INDEX tmp_ix_clientes_nome_upper REBUILD;

-- Esperado: todos VALID
SELECT index_name, status FROM user_indexes WHERE table_name = 'TMP_CLIENTES' ORDER BY index_name;

-- [12.2+] ALTER TABLE ... MOVE ONLINE mantém os índices válidos.

-- 8. Tamanho de tabelas e índices.
-- Esperado: INDEX 18 1152 | TABLE 7 448 (cada segmento com o primeiro extent, normalmente 64 KB)
SELECT segment_type, COUNT(*) AS segmentos, SUM(bytes) / 1024 AS kb
  FROM user_segments
 WHERE segment_name NOT LIKE 'TMP%'
   AND segment_name NOT LIKE 'BIN$%'
 GROUP BY segment_type
 ORDER BY segment_type;

DROP TABLE tmp_clientes PURGE;
