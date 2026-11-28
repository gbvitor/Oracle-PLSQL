-- =============================================================================
-- Tópico : Parse, hard parse e soft parse medidos pelas estatísticas da sessão
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql; leitura de V$MYSTAT e V$SQL (SELECT_CATALOG_ROLE)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- Contadores de parse da própria sessão.
CREATE OR REPLACE VIEW tmp_vw_parse AS
SELECT n.name, m.value
  FROM v$mystat m
  JOIN v$statname n ON n.statistic# = m.statistic#
 WHERE n.name IN ('parse count (total)', 'parse count (hard)', 'execute count');
-- (se der ORA-01031, o privilégio veio por role: rode as consultas sem a view)

-- 1. 500 consultas com literal: um texto novo por valor.
DECLARE
    v_antes  NUMBER;
    v_depois NUMBER;
    v        NUMBER;
BEGIN
    SELECT value INTO v_antes FROM tmp_vw_parse WHERE name = 'parse count (hard)';

    FOR i IN 1 .. 500 LOOP
        EXECUTE IMMEDIATE 'SELECT /* tmp_lit */ valor FROM tmp_perf_pedidos WHERE id_pedido = ' || i INTO v;
    END LOOP;

    SELECT value INTO v_depois FROM tmp_vw_parse WHERE name = 'parse count (hard)';
    DBMS_OUTPUT.PUT_LINE('Literal: hard parses = ' || (v_depois - v_antes));
END;
/
-- Esperado: Literal: hard parses = 500 (ou pouco mais)

-- 2. As mesmas 500 com bind: um texto só.
DECLARE
    v_antes  NUMBER;
    v_depois NUMBER;
    v        NUMBER;
BEGIN
    SELECT value INTO v_antes FROM tmp_vw_parse WHERE name = 'parse count (hard)';

    FOR i IN 1 .. 500 LOOP
        EXECUTE IMMEDIATE 'SELECT /* tmp_bind */ valor FROM tmp_perf_pedidos WHERE id_pedido = :id' INTO v USING i;
    END LOOP;

    SELECT value INTO v_depois FROM tmp_vw_parse WHERE name = 'parse count (hard)';
    DBMS_OUTPUT.PUT_LINE('Bind:    hard parses = ' || (v_depois - v_antes));
END;
/
-- Esperado: Bind:    hard parses = 1 (ou 0, se o texto já estava no shared pool)

-- 3. O que ficou no shared pool.
-- Esperado: tmp_lit 500 cursores, 1 execução cada | tmp_bind 1 cursor, 500 execuções
SELECT CASE WHEN sql_text LIKE '%tmp_lit%' THEN 'tmp_lit' ELSE 'tmp_bind' END AS forma,
       COUNT(*)        AS cursores,
       SUM(executions) AS execucoes
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /* tmp_lit */%' OR sql_text LIKE 'SELECT /* tmp_bind */%'
 GROUP BY CASE WHEN sql_text LIKE '%tmp_lit%' THEN 'tmp_lit' ELSE 'tmp_bind' END;

-- 4. Diferença de texto, mesmo significado: cursores diferentes.
SELECT /* tmp_txt */ COUNT(*) FROM tmp_perf_clientes WHERE uf = 'TO';
select /* tmp_txt */ count(*) from tmp_perf_clientes where uf = 'TO';
SELECT /* tmp_txt */ COUNT(*)  FROM tmp_perf_clientes WHERE uf = 'TO';

-- Esperado: 3 linhas, com sql_id diferentes (maiúsculas e um espaço a mais bastam)
SELECT sql_id, executions, sql_text
  FROM v$sql
 WHERE UPPER(sql_text) LIKE 'SELECT /* TMP_TXT */%';

-- 5. SQL estático em PL/SQL usa bind sozinho.
DECLARE
    v NUMBER;
BEGIN
    FOR i IN 1 .. 50 LOOP
        SELECT valor INTO v FROM tmp_perf_pedidos WHERE id_pedido = i;
    END LOOP;
END;
/

-- O PL/SQL reescreve o SQL estático: maiúsculas, espaços normalizados, comentários
-- removidos (só hints ficam) e cada variável trocada por um bind :B1, :B2...
-- Esperado: 1 cursor com 50 execuções (ou mais, se o passo já rodou antes)
SELECT sql_id, executions, sql_text
  FROM v$sql
 WHERE sql_text LIKE 'SELECT VALOR FROM TMP_PERF_PEDIDOS WHERE ID_PEDIDO = :B1%';

DROP VIEW tmp_vw_parse;
