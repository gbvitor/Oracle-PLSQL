-- =============================================================================
-- Tópico : Lendo um plano — métodos de acesso e de junção
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql
--
-- Os planos esperados são os mais prováveis com as estatísticas de 00-preparar;
-- o otimizador pode escolher outro caminho em versões ou configurações diferentes.
-- Quando isso acontecer, compare as estimativas (Rows) para entender o motivo.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 200

-- Atalho: explicar e mostrar operações, linhas estimadas e predicados.
-- (cada bloco abaixo repete o par EXPLAIN PLAN / DISPLAY)

-- 1. INDEX UNIQUE SCAN: igualdade na chave primária.
EXPLAIN PLAN FOR SELECT * FROM tmp_perf_pedidos WHERE id_pedido = 4242;
-- Esperado: TABLE ACCESS BY INDEX ROWID | INDEX UNIQUE SCAN PK_TMP_PERF_PEDIDOS | Rows 1
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 2. INDEX RANGE SCAN: faixa de datas.
EXPLAIN PLAN FOR
SELECT * FROM tmp_perf_pedidos WHERE data_pedido >= DATE '2025-03-10' AND data_pedido < DATE '2025-03-11';
-- Esperado: TABLE ACCESS BY INDEX ROWID BATCHED | INDEX RANGE SCAN TMP_IX_PERF_PED_DATA | Rows ~274
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 3. TABLE ACCESS FULL: fração grande da tabela.
EXPLAIN PLAN FOR SELECT * FROM tmp_perf_pedidos WHERE data_pedido >= DATE '2025-01-01';
-- Esperado: TABLE ACCESS FULL | Rows ~99900 (metade dos dois anos)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 4. Índice que cobre a consulta: sem acesso à tabela.
EXPLAIN PLAN FOR
SELECT data_pedido FROM tmp_perf_pedidos WHERE data_pedido >= DATE '2025-03-10' AND data_pedido < DATE '2025-03-11';
-- Esperado: só INDEX RANGE SCAN TMP_IX_PERF_PED_DATA (nenhum TABLE ACCESS)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 5. INDEX FAST FULL SCAN: contar usando o índice como uma tabela menor.
EXPLAIN PLAN FOR SELECT COUNT(*) FROM tmp_perf_pedidos;
-- Esperado: SORT AGGREGATE | INDEX FAST FULL SCAN (de algum índice em coluna NOT NULL,
--           normalmente o menor: o de status ou o da PK)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

-- 6. INDEX FULL SCAN: ler em ordem para evitar SORT.
EXPLAIN PLAN FOR SELECT id_pedido FROM tmp_perf_pedidos ORDER BY id_pedido;
-- Esperado: INDEX FULL SCAN PK_TMP_PERF_PEDIDOS, sem SORT ORDER BY
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

-- 7. INDEX SKIP SCAN: índice composto, filtro só na segunda coluna.
CREATE INDEX tmp_ix_perf_ped_status_valor ON tmp_perf_pedidos (status, valor);

EXPLAIN PLAN FOR SELECT status, valor FROM tmp_perf_pedidos WHERE valor = 15.29;
-- Esperado: INDEX SKIP SCAN TMP_IX_PERF_PED_STATUS_VALOR (status tem só 3 valores:
--           o Oracle faz três buscas, uma por status). Pode aparecer INDEX FAST FULL SCAN.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

DROP INDEX tmp_ix_perf_ped_status_valor;

-- 8. NESTED LOOPS: poucas linhas na externa, índice na interna.
EXPLAIN PLAN FOR
SELECT c.nome, p.id_pedido, p.valor
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 WHERE c.id_cliente = 42;
-- Esperado: NESTED LOOPS
--             TABLE ACCESS BY INDEX ROWID TMP_PERF_CLIENTES / INDEX UNIQUE SCAN  (externa: 1 linha)
--             TABLE ACCESS BY INDEX ROWID BATCHED TMP_PERF_PEDIDOS / INDEX RANGE SCAN (interna: 100)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 9. HASH JOIN: muitas linhas dos dois lados.
EXPLAIN PLAN FOR
SELECT c.uf, SUM(p.valor)
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 GROUP BY c.uf;
-- Esperado: HASH GROUP BY
--             HASH JOIN
--               TABLE ACCESS FULL TMP_PERF_CLIENTES   (a menor: vira a tabela hash)
--               TABLE ACCESS FULL TMP_PERF_PEDIDOS
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 10. MERGE JOIN: forçado com hint, só para ver a forma (tópico 08).
EXPLAIN PLAN FOR
SELECT /*+ USE_MERGE(p) */ c.uf, SUM(p.valor)
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 GROUP BY c.uf;
-- Esperado: MERGE JOIN com SORT JOIN nos dois lados (ou um lado lido em ordem por índice)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

-- 11. Junção por desigualdade: hash join não serve.
EXPLAIN PLAN FOR
SELECT COUNT(*)
  FROM tmp_perf_clientes a
  JOIN tmp_perf_clientes b ON b.id_cliente BETWEEN a.id_cliente AND a.id_cliente + 2;
-- Esperado: MERGE JOIN ou NESTED LOOPS, nunca HASH JOIN (hash exige igualdade)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

-- 12. Ordem de leitura: numere as operações na ordem em que executam.
EXPLAIN PLAN FOR
SELECT c.segmento, COUNT(*)
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 WHERE p.data_pedido >= DATE '2025-12-01'
 GROUP BY c.segmento
 ORDER BY 2 DESC;
-- Esperado (forma provável) e ordem de execução:
--   0 SELECT STATEMENT
--   1   SORT ORDER BY                       <- 6º
--   2     HASH GROUP BY                     <- 5º
--   3       HASH JOIN                       <- 4º
--   4         TABLE ACCESS FULL CLIENTES    <- 1º (vira a hash)
--   5         TABLE ACCESS BY INDEX ROWID BATCHED PEDIDOS  <- 3º
--   6           INDEX RANGE SCAN DATA       <- 2º
--   (Ou TABLE ACCESS FULL em pedidos, se o otimizador achar 8480 linhas espalhadas demais.)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));
