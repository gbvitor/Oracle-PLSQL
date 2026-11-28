-- =============================================================================
-- Tópico : EXPLAIN PLAN e DBMS_XPLAN.DISPLAY — formatos, predicados, limites
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql
--
-- Os planos esperados descrevem a forma (operações e predicados). Custo, bytes
-- e tempo variam com a versão, o tamanho de bloco e as estatísticas do sistema.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 200

-- 1. O básico.
EXPLAIN PLAN FOR
SELECT * FROM tmp_perf_pedidos WHERE id_cliente = 42;

-- Esperado:
--   SELECT STATEMENT
--     TABLE ACCESS BY INDEX ROWID BATCHED | TMP_PERF_PEDIDOS  | Rows 100
--       INDEX RANGE SCAN                  | TMP_IX_PERF_PED_CLIENTE | Rows 100
--   Predicate: 2 - access("ID_CLIENTE"=42)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- 2. Formatos.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'TYPICAL +ALIAS -BYTES'));
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'ALL'));

-- +OUTLINE: os hints que reproduzem exatamente este plano.
-- Esperado: bloco "Outline Data" com INDEX_RS_ASC(... "TMP_IX_PERF_PED_CLIENTE") e similares
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +OUTLINE'));

-- 3. access versus filter.
EXPLAIN PLAN SET STATEMENT_ID = 'tmp_filtro' FOR
SELECT * FROM tmp_perf_pedidos WHERE id_cliente = 42 AND valor > 1000;

-- Esperado: 2 - access("ID_CLIENTE"=42)  (no índice)
--           1 - filter("VALOR">1000)      (na tabela, depois de ler as 100 linhas)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'tmp_filtro'));

-- Sem índice que sirva: tudo é filter numa leitura completa.
EXPLAIN PLAN SET STATEMENT_ID = 'tmp_full' FOR
SELECT * FROM tmp_perf_pedidos WHERE valor BETWEEN 100 AND 101;

-- Esperado: TABLE ACCESS FULL | TMP_PERF_PEDIDOS
--           1 - filter("VALOR">=100 AND "VALOR"<=101)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'tmp_full'));

-- 4. Rows estimado: o número que o otimizador imagina.
EXPLAIN PLAN SET STATEMENT_ID = 'tmp_status' FOR
SELECT * FROM tmp_perf_pedidos WHERE status = 'CANCELADO';

-- Esperado: Rows perto de 66667 (200000 / 3 valores distintos), embora sejam 200.
--           Sem histograma, o otimizador supõe distribuição uniforme (tópico 05).
--           Com essa estimativa, provavelmente escolhe TABLE ACCESS FULL.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'tmp_status'));

-- 5. Nota de estatísticas dinâmicas: tabela sem estatísticas.
CREATE TABLE tmp_sem_stats AS SELECT * FROM tmp_perf_clientes;
BEGIN
    DBMS_STATS.DELETE_TABLE_STATS(USER, 'TMP_SEM_STATS');
END;
/

EXPLAIN PLAN SET STATEMENT_ID = 'tmp_dyn' FOR
SELECT * FROM tmp_sem_stats WHERE uf = 'TO';

-- Esperado: Note: dynamic statistics used: dynamic sampling (level=2)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'tmp_dyn'));

DROP TABLE tmp_sem_stats PURGE;

-- 6. O limite: bind no EXPLAIN PLAN é tratado como VARCHAR2.
--    Coluna VARCHAR2 com bind NUMBER na execução real não aparece igual aqui.
VARIABLE cod NUMBER
EXEC :cod := 100042

EXPLAIN PLAN SET STATEMENT_ID = 'tmp_bind' FOR
SELECT * FROM tmp_perf_clientes WHERE codigo_ext = :cod;

-- Esperado: INDEX RANGE SCAN em TMP_IX_PERF_CLI_CODIGO, access("CODIGO_EXT"=:COD)
--           (o EXPLAIN PLAN imagina o bind como texto)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'tmp_bind'));

-- Na execução real, o bind é NUMBER: o Oracle converte a COLUNA (TO_NUMBER("CODIGO_EXT"))
-- e o índice deixa de servir. O tópico 03 mostra o plano real; o tópico 06, o motivo.

-- 7. PLAN_TABLE é temporária: cada sessão vê só os próprios planos, que somem ao fim da sessão.
-- Esperado: as linhas dos planos gravados nesta sessão
SELECT statement_id, COUNT(*) AS operacoes
  FROM plan_table
 GROUP BY statement_id
 ORDER BY statement_id;
