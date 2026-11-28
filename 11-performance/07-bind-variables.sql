-- =============================================================================
-- Tópico : Bind peeking e adaptive cursor sharing com distribuição torta
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql; leitura de V$SQL. O script cria o histograma em
--          status e remove no fim.
--
-- O momento exato em que o cursor vira bind aware depende da versão e de
-- heurísticas internas: os passos dizem o que observar, não em que execução.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET SERVEROUTPUT OFF

COLUMN sql_text FORMAT A50 TRUNCATED

-- Histograma em status, condição para o adaptive cursor sharing agir.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PERF_PEDIDOS', method_opt => 'FOR COLUMNS status SIZE 254', cascade => FALSE);
END;
/

-- Para repetir o roteiro do zero, troque o marcador tmp_acs por outro (tmp_acs2...):
-- um texto novo começa sem cursores antigos no shared pool.
VARIABLE st VARCHAR2(12)

-- 1. Primeira execução com valor raro: o plano nasce para ele.
EXEC :st := 'CANCELADO'
SELECT /* tmp_acs */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = :st;

-- Esperado: INDEX RANGE SCAN TMP_IX_PERF_PED_STATUS; Peeked Binds: :ST = 'CANCELADO'
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'TYPICAL +PEEKED_BINDS'));

-- 2. Valor frequente reaproveita o plano do índice.
EXEC :st := 'ENTREGUE'
SELECT /* tmp_acs */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = :st;

-- Esperado: o mesmo child 0 com INDEX RANGE SCAN, agora para 197800 linhas
--           (o plano errado para este valor)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'TYPICAL +PEEKED_BINDS'));

-- Esperado: child 0 | executions 2 | is_bind_sensitive Y | is_bind_aware N (ainda)
SELECT sql_id, child_number, executions, buffer_gets, is_bind_sensitive, is_bind_aware, is_shareable, sql_text
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /* tmp_acs */%'
 ORDER BY child_number;

-- 3. Mais execuções com o valor frequente: o Oracle percebe a diferença de volume.
EXEC :st := 'ENTREGUE'
SELECT /* tmp_acs */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = :st;
SELECT /* tmp_acs */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = :st;

-- Esperado: um novo child (1), bind aware, com TABLE ACCESS FULL para ENTREGUE.
--           O child 0 pode ficar is_shareable = N (substituído).
SELECT sql_id, child_number, executions, buffer_gets, is_bind_sensitive, is_bind_aware, is_shareable, sql_text
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /* tmp_acs */%'
 ORDER BY child_number;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'TYPICAL +PEEKED_BINDS'));

-- 4. De volta ao valor raro: com o cursor bind aware, ele recebe o plano certo.
EXEC :st := 'CANCELADO'
SELECT /* tmp_acs */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = :st;

-- Esperado: child com INDEX RANGE SCAN (um dos existentes ou um novo)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'TYPICAL +PEEKED_BINDS'));

-- Resumo dos filhos: um plano por faixa de seletividade.
-- Esperado: dois plan_hash_value diferentes entre os filhos compartilháveis
SELECT child_number, plan_hash_value, executions, is_bind_aware, is_shareable
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /* tmp_acs */%'
 ORDER BY child_number;

-- 5. A seletividade que o Oracle guardou por filho.
-- Esperado: faixas de seletividade (low, high) por child bind aware
SELECT child_number, predicate, low, high
  FROM v$sql_cs_selectivity
 WHERE sql_id = (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /* tmp_acs */%' FETCH FIRST 1 ROW ONLY)
 ORDER BY child_number;

-- 6. O EXPLAIN PLAN não espia o bind: mostra um plano "genérico".
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = :st;
-- Esperado: uma estimativa genérica, que não corresponde a nenhum dos valores
--           espiados acima (o plano mostrado pode não ser o que as execuções usam)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

-- Voltar ao estado de 00-preparar (sem histograma).
BEGIN
    DBMS_STATS.DELETE_COLUMN_STATS(USER, 'TMP_PERF_PEDIDOS', 'STATUS', col_stat_type => 'HISTOGRAM');
END;
/
