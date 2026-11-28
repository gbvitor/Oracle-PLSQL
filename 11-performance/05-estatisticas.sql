-- =============================================================================
-- Tópico : Estatísticas — o que há no dicionário, histograma em distribuição
--          torta, estatística desatualizada e valor fora da faixa
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql. O script devolve a tabela ao estado de 00-preparar
--          no fim (sem histograma), para os outros tópicos.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET SERVEROUTPUT OFF

COLUMN column_name FORMAT A12
COLUMN histogram   FORMAT A16
COLUMN valor       FORMAT A12

-- 1. Estatísticas de coluna, sem histograma.
-- Esperado: STATUS num_distinct 3, histogram NONE, num_buckets 1;
--           ID_CLIENTE num_distinct 2000; DATA_PEDIDO perto de 200000 (tem hora)
SELECT column_name, num_distinct, num_nulls, histogram, num_buckets, last_analyzed
  FROM user_tab_col_statistics
 WHERE table_name = 'TMP_PERF_PEDIDOS'
 ORDER BY column_name;

-- 2. A estimativa uniforme, para os três status.
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*) FROM tmp_perf_pedidos WHERE status = 'CANCELADO';
-- Esperado: E-Rows 66667 | A-Rows 200 | TABLE ACCESS FULL
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 3. Histograma na coluna status.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PERF_PEDIDOS',
                                  method_opt => 'FOR COLUMNS status SIZE 254',
                                  cascade    => FALSE);
END;
/

-- Esperado: STATUS histogram FREQUENCY, num_buckets 3
SELECT column_name, num_distinct, histogram, num_buckets
  FROM user_tab_col_statistics
 WHERE table_name = 'TMP_PERF_PEDIDOS' AND column_name = 'STATUS';

-- O histograma: ENDPOINT_NUMBER é acumulado (2000, 2200, 200000).
-- Esperado: ABERTO 2000 | CANCELADO 2200 | ENTREGUE 200000
--           (endpoint_actual_value pode vir vazio; a ordem é a dos valores)
SELECT endpoint_number,
       endpoint_number - LAG(endpoint_number, 1, 0) OVER (ORDER BY endpoint_number) AS linhas,
       endpoint_actual_value AS valor
  FROM user_tab_histograms
 WHERE table_name = 'TMP_PERF_PEDIDOS' AND column_name = 'STATUS'
 ORDER BY endpoint_number;

-- 4. Com histograma, cada valor tem a sua estimativa e o seu plano.
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = 'CANCELADO';
-- Esperado: E-Rows 200 | A-Rows 200 | INDEX RANGE SCAN TMP_IX_PERF_PED_STATUS
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = 'ENTREGUE';
-- Esperado: E-Rows 197800 | A-Rows 197800 | TABLE ACCESS FULL
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 5. Estatística desatualizada: 100 mil pedidos novos, ABERTO, em 2026 e 2027.
INSERT INTO tmp_perf_pedidos
SELECT id_pedido + 200000, id_cliente, data_pedido + 731, 'ABERTO', valor, observacao
  FROM tmp_perf_pedidos
 WHERE id_pedido <= 100000;
COMMIT;

-- Gravar as contagens de DML no dicionário (pode exigir privilégio; se der erro,
-- o Oracle grava sozinho em alguns minutos).
EXEC DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO

-- Esperado: num_rows 200000 (o dicionário ainda não sabe) | inserts 100000 | stale_stats YES
SELECT s.num_rows, m.inserts, s.stale_stats
  FROM user_tab_statistics s
  LEFT JOIN user_tab_modifications m ON m.table_name = s.table_name AND m.partition_name IS NULL
 WHERE s.table_name = 'TMP_PERF_PEDIDOS';

-- O histograma diz 2000 ABERTOS; agora são 102000.
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = 'ABERTO';
-- Esperado: E-Rows 2000 | A-Rows 102000 | INDEX RANGE SCAN + TABLE ACCESS BY INDEX ROWID:
--           o plano certo para 2000, o errado para 102000 (Buffers bem maior que a leitura completa)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- Valor fora da faixa: o máximo conhecido de data_pedido é 2025-12-31.
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*) FROM tmp_perf_pedidos WHERE data_pedido >= DATE '2026-06-01';
-- Esperado: E-Rows muito pequeno (o otimizador acha que quase não há datas depois do máximo)
--           contra A-Rows 79338
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 6. Coletar de novo resolve as duas estimativas.
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PERF_PEDIDOS', method_opt => 'FOR COLUMNS status SIZE 254')

SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = 'ABERTO';
-- Esperado: E-Rows ~102000 | A-Rows 102000 | TABLE ACCESS FULL
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 7. Histórico: as estatísticas anteriores ficam guardadas e podem ser restauradas.
COLUMN stats_update_time FORMAT A40
-- Esperado: uma linha por coleta feita neste script e em 00-preparar
SELECT stats_update_time FROM user_tab_stats_history WHERE table_name = 'TMP_PERF_PEDIDOS' ORDER BY 1;

-- 8. Voltar ao estado de 00-preparar.
DELETE FROM tmp_perf_pedidos WHERE id_pedido > 200000;
COMMIT;

BEGIN
    DBMS_STATS.DELETE_COLUMN_STATS(USER, 'TMP_PERF_PEDIDOS', 'STATUS', col_stat_type => 'HISTOGRAM');
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PERF_PEDIDOS', method_opt => 'FOR ALL COLUMNS SIZE 1', cascade => TRUE);
END;
/

-- Esperado: 200000 | STATUS histogram NONE
SELECT t.num_rows, c.histogram
  FROM user_tab_statistics t
  JOIN user_tab_col_statistics c ON c.table_name = t.table_name AND c.column_name = 'STATUS'
 WHERE t.table_name = 'TMP_PERF_PEDIDOS';
