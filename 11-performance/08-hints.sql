-- =============================================================================
-- Tópico : Hints — acesso, junção, alias, hint ignorado, HINT_REPORT,
--          comparação de planos para diagnóstico
-- Seção  : 11-performance
-- Versão : 19c (HINT_REPORT exige 19c+)
-- Requer : 00-preparar.sql
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 300
SET SERVEROUTPUT OFF

-- 1. Diagnóstico: o plano escolhido contra o plano forçado, medidos.
SELECT /*+ GATHER_PLAN_STATISTICS */ SUM(valor) FROM tmp_perf_pedidos p WHERE id_cliente = 42;
-- Esperado: INDEX RANGE SCAN + TABLE ACCESS BY INDEX ROWID BATCHED; Buffers na casa de 100
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

SELECT /*+ GATHER_PLAN_STATISTICS FULL(p) */ SUM(valor) FROM tmp_perf_pedidos p WHERE id_cliente = 42;
-- Esperado: TABLE ACCESS FULL; Buffers na casa de milhares (todos os blocos da tabela).
--           O otimizador tinha razão: o hint serviu para confirmar.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 2. O caso inverso: o otimizador erra por falta de histograma (tópico 05).
SELECT /*+ GATHER_PLAN_STATISTICS */ SUM(valor) FROM tmp_perf_pedidos p WHERE status = 'CANCELADO';
-- Esperado: TABLE ACCESS FULL, E-Rows 66667, A-Rows 200, Buffers ~ todos os blocos
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

SELECT /*+ GATHER_PLAN_STATISTICS INDEX(p tmp_ix_perf_ped_status) */ SUM(valor)
  FROM tmp_perf_pedidos p
 WHERE status = 'CANCELADO';
-- Esperado: INDEX RANGE SCAN, Buffers na casa de 200: muito menos.
--           Conclusão certa: falta histograma em status. O hint não é a correção.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 3. [19c+] Hint ignorado: alias errado, índice inexistente, erro de digitação.
SELECT /*+ FULL(tmp_perf_pedidos) INDEX(p tmp_ix_nao_existe) USE_HAHS(p) */ SUM(valor)
  FROM tmp_perf_pedidos p
 WHERE id_cliente = 42;

-- Esperado: plano igual ao do passo 1 (nenhum hint aplicado) e o relatório:
--   Hint Report (identified by operation id / Query Block Name / Object Alias):
--   Total hints for statement: 3 (U - Unused (2), E - Syntax error (1))
--     E - USE_HAHS
--     U - FULL(tmp_perf_pedidos)   (a tabela tem alias p)
--     U - INDEX(p tmp_ix_nao_existe)
--   (a classificação e o texto exatos de cada linha podem variar com a versão)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'TYPICAL +HINT_REPORT'));

-- 4. Hint depois de um comentário comum: pode ser ignorado.
SELECT /* comentario */ /*+ FULL(p) */ SUM(valor) FROM tmp_perf_pedidos p WHERE id_cliente = 42;
-- Esperado: provavelmente INDEX RANGE SCAN e nenhum hint no relatório: o hint precisa
--           ser o primeiro comentário depois do SELECT
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'BASIC +HINT_REPORT'));

-- 5. Ordem e método de junção.
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*)
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 WHERE c.uf = 'TO';
-- Esperado: HASH JOIN, CLIENTES primeiro (200 clientes), PEDIDOS em leitura completa
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

SELECT /*+ GATHER_PLAN_STATISTICS LEADING(c) USE_NL(p) INDEX(p tmp_ix_perf_ped_cliente) */ COUNT(*)
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 WHERE c.uf = 'TO';
-- Esperado: NESTED LOOPS; a busca no índice de PEDIDOS com Starts 200 (uma por cliente).
--           Compare Buffers e A-Time com o anterior: para 20000 linhas, os dois são
--           próximos; com mais clientes, o hash join se distancia.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));

-- 6. FIRST_ROWS: otimizar para as primeiras linhas de uma tela paginada.
EXPLAIN PLAN FOR
SELECT * FROM tmp_perf_pedidos ORDER BY data_pedido DESC FETCH FIRST 20 ROWS ONLY;
-- Esperado: INDEX FULL SCAN DESCENDING em TMP_IX_PERF_PED_DATA + acesso à tabela,
--           parando em 20 linhas (sem ordenar a tabela inteira)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

EXPLAIN PLAN FOR
SELECT /*+ FULL(p) */ * FROM tmp_perf_pedidos p ORDER BY data_pedido DESC FETCH FIRST 20 ROWS ONLY;
-- Esperado: TABLE ACCESS FULL + WINDOW SORT PUSHED RANK: lê e ordena (parcialmente) tudo
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS'));

-- 7. MATERIALIZE e INLINE em WITH.
EXPLAIN PLAN FOR
WITH totais AS (
    SELECT /*+ MATERIALIZE */ id_cliente, SUM(valor) AS total
      FROM tmp_perf_pedidos
     GROUP BY id_cliente
)
SELECT c.uf, SUM(t.total) FROM totais t JOIN tmp_perf_clientes c ON c.id_cliente = t.id_cliente GROUP BY c.uf;
-- Esperado: TEMP TABLE TRANSFORMATION + LOAD AS SELECT (o WITH vira tabela temporária)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 8. O conjunto de hints que reproduz um plano: +OUTLINE.
EXPLAIN PLAN FOR
SELECT c.uf, SUM(p.valor) FROM tmp_perf_clientes c JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente GROUP BY c.uf;
-- Esperado: Outline Data com LEADING(@"SEL$..." "C"@"SEL$1" "P"@"SEL$1"), USE_HASH(...),
--           FULL(...): é o que um SQL Plan Baseline guarda para fixar este plano
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +OUTLINE'));
