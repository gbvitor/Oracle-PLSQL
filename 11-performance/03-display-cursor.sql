-- =============================================================================
-- Tópico : Plano real — DBMS_XPLAN.DISPLAY_CURSOR, GATHER_PLAN_STATISTICS,
--          E-Rows contra A-Rows
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql (sem ter rodado o tópico 05, que cria o histograma);
--          leitura de V$SQL e V$SQL_PLAN (SELECT_CATALOG_ROLE)
-- =============================================================================

SET LINESIZE 220
SET PAGESIZE 300
SET SERVEROUTPUT OFF

-- 1. A estimativa errada, medida.
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*), SUM(valor)
  FROM tmp_perf_pedidos
 WHERE status = 'CANCELADO';

-- Esperado (forma):
--   | Id | Operation          | Name             | Starts | E-Rows | A-Rows | Buffers |
--   |  0 | SELECT STATEMENT   |                  |      1 |        |      1 |         |
--   |  1 |  SORT AGGREGATE    |                  |      1 |      1 |      1 |         |
--   |* 2 |   TABLE ACCESS FULL| TMP_PERF_PEDIDOS |      1 |  66667 |    200 |  ~2500  |
--   E-Rows 66667 contra A-Rows 200: erro de 333 vezes. Por isso a leitura completa.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 2. Com SERVEROUTPUT ligado, o "último SQL" é a chamada do DBMS_OUTPUT.
SET SERVEROUTPUT ON
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*) FROM tmp_perf_pedidos WHERE id_cliente = 42;

-- Esperado: plano de "BEGIN DBMS_OUTPUT.GET_LINES(...)" ou a nota
--           "cannot fetch plan for SQL_ID", e não o da consulta acima
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));
SET SERVEROUTPUT OFF

-- 3. Achar o SQL_ID pelo texto e mostrar o plano de qualquer cursor.
SELECT /*+ GATHER_PLAN_STATISTICS */ /* tmp_marcador_03 */ COUNT(*)
  FROM tmp_perf_pedidos p
  JOIN tmp_perf_clientes c ON c.id_cliente = p.id_cliente
 WHERE c.segmento = 'ATACADO';

-- Esperado: um sql_id, child_number 0
COLUMN sql_text FORMAT A60 TRUNCATED
SELECT sql_id, child_number, executions, sql_text
  FROM v$sql
 WHERE sql_text LIKE '%tmp_marcador_03%'
   AND sql_text NOT LIKE '%v$sql%';

-- Troque o sql_id abaixo pelo que apareceu (ou use a forma sem argumentos logo
-- depois de executar a consulta).
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('sql_id_aqui', 0, 'ALLSTATS LAST'));

-- Versão que acha sozinha o cursor mais recente com o marcador:
SELECT t.*
  FROM (SELECT sql_id, child_number
          FROM v$sql
         WHERE sql_text LIKE '%tmp_marcador_03%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) s,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(s.sql_id, s.child_number, 'ALLSTATS LAST')) t;
-- Esperado: HASH JOIN entre TMP_PERF_CLIENTES (filtrado por segmento: E-Rows 1000,
--           A-Rows 100) e TMP_PERF_PEDIDOS (E-Rows/A-Rows 200000); resultado A-Rows 1,
--           com COUNT 10000 (100 clientes de atacado x 100 pedidos)
--           A estimativa do segmento erra 10 vezes pelo mesmo motivo do passo 1:
--           2 valores distintos, distribuição 95% / 5%.

-- 4. statistics_level = ALL: estatísticas de execução sem hint.
ALTER SESSION SET statistics_level = ALL;

SELECT COUNT(*) FROM tmp_perf_pedidos WHERE data_pedido >= DATE '2025-12-01';

-- Esperado: A-Rows 8480 (31 dias de dezembro de 2025);
--           E-Rows próximo disso (data tem distribuição uniforme, a estimativa acerta)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

ALTER SESSION SET statistics_level = TYPICAL;

-- 5. O plano real de um bind de tipo diferente da coluna (ver tópico 02, passo 6).
VARIABLE cod NUMBER
EXEC :cod := 100042

SELECT /*+ GATHER_PLAN_STATISTICS */ id_cliente, nome FROM tmp_perf_clientes WHERE codigo_ext = :cod;

-- Esperado: TABLE ACCESS FULL | TMP_PERF_CLIENTES
--           filter(TO_NUMBER("CODIGO_EXT")=:COD)
--           O EXPLAIN PLAN do tópico 02 previa INDEX RANGE SCAN: aqui está a diferença.
--           Com +PEEKED_BINDS, a seção "Peeked Binds" mostra :COD (NUMBER) = 100042.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST +PEEKED_BINDS'));

-- O mesmo com bind do tipo certo: o índice volta.
VARIABLE cod_txt VARCHAR2(10)
EXEC :cod_txt := '100042'

SELECT /*+ GATHER_PLAN_STATISTICS */ id_cliente, nome FROM tmp_perf_clientes WHERE codigo_ext = :cod_txt;

-- Esperado: INDEX RANGE SCAN | TMP_IX_PERF_CLI_CODIGO, access("CODIGO_EXT"=:COD_TXT), A-Rows 1
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));
