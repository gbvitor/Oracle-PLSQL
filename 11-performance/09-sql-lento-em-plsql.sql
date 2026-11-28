-- =============================================================================
-- Tópico : SQL lento em PL/SQL — linha a linha, FORALL e uma instrução;
--          N+1 consultas; function no SELECT
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql; CREATE PROCEDURE
--
-- Os tempos dependem da máquina. O que vale observar é a proporção entre as
-- formas. Os passos 1 a 4 trabalham sobre 20 mil pedidos para não demorar demais.
-- Regra do exemplo: pedidos de clientes ATACADO têm o valor reduzido em 5%;
-- os de VAREJO, aumentado em 2%.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Linha a linha, com consulta de apoio e COMMIT por linha (o pior caso).
--    Numa cópia, porque o COMMIT grava de verdade.
CREATE TABLE tmp_perf_copia AS SELECT * FROM tmp_perf_pedidos WHERE id_pedido <= 20000;
ALTER TABLE tmp_perf_copia ADD CONSTRAINT pk_tmp_perf_copia PRIMARY KEY (id_pedido);

DECLARE
    v_inicio   PLS_INTEGER := DBMS_UTILITY.GET_TIME;
    v_segmento tmp_perf_clientes.segmento%TYPE;
    v_qtd      PLS_INTEGER := 0;
BEGIN
    FOR r IN (SELECT id_pedido, id_cliente FROM tmp_perf_copia) LOOP
        SELECT segmento INTO v_segmento FROM tmp_perf_clientes WHERE id_cliente = r.id_cliente;

        UPDATE tmp_perf_copia
           SET valor = ROUND(valor * CASE v_segmento WHEN 'ATACADO' THEN 0.95 ELSE 1.02 END, 2)
         WHERE id_pedido = r.id_pedido;

        COMMIT;
        v_qtd := v_qtd + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('1. linha a linha + COMMIT: ' || v_qtd || ' linhas em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
END;
/

DROP TABLE tmp_perf_copia PURGE;

-- 2. Linha a linha, junção no cursor, sem COMMIT por linha.
DECLARE
    v_inicio PLS_INTEGER := DBMS_UTILITY.GET_TIME;
    v_qtd    PLS_INTEGER := 0;
BEGIN
    FOR r IN (SELECT p.id_pedido, c.segmento
                FROM tmp_perf_pedidos p
                JOIN tmp_perf_clientes c ON c.id_cliente = p.id_cliente
               WHERE p.id_pedido <= 20000) LOOP
        UPDATE tmp_perf_pedidos
           SET valor = ROUND(valor * CASE r.segmento WHEN 'ATACADO' THEN 0.95 ELSE 1.02 END, 2)
         WHERE id_pedido = r.id_pedido;
        v_qtd := v_qtd + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('2. linha a linha:          ' || v_qtd || ' linhas em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
    ROLLBACK;
END;
/

-- 3. BULK COLLECT + FORALL.
DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_ids    t_num;
    v_fator  t_num;
    v_inicio PLS_INTEGER := DBMS_UTILITY.GET_TIME;
BEGIN
    SELECT p.id_pedido, CASE c.segmento WHEN 'ATACADO' THEN 0.95 ELSE 1.02 END
      BULK COLLECT INTO v_ids, v_fator
      FROM tmp_perf_pedidos p
      JOIN tmp_perf_clientes c ON c.id_cliente = p.id_cliente
     WHERE p.id_pedido <= 20000;

    FORALL i IN 1 .. v_ids.COUNT
        UPDATE tmp_perf_pedidos SET valor = ROUND(valor * v_fator(i), 2) WHERE id_pedido = v_ids(i);

    DBMS_OUTPUT.PUT_LINE('3. FORALL:                 ' || SQL%ROWCOUNT || ' linhas em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
    ROLLBACK;
END;
/

-- 4. Uma instrução.
DECLARE
    v_inicio PLS_INTEGER := DBMS_UTILITY.GET_TIME;
BEGIN
    UPDATE tmp_perf_pedidos p
       SET valor = ROUND(valor * (SELECT CASE c.segmento WHEN 'ATACADO' THEN 0.95 ELSE 1.02 END
                                    FROM tmp_perf_clientes c
                                   WHERE c.id_cliente = p.id_cliente), 2)
     WHERE p.id_pedido <= 20000;

    DBMS_OUTPUT.PUT_LINE('4. um UPDATE:              ' || SQL%ROWCOUNT || ' linhas em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
    ROLLBACK;
END;
/
-- Esperado: 20000 linhas em cada forma; tempos decrescentes de 1 para 4.
--           Proporção típica: o passo 1 várias vezes mais lento que o 2 (o COMMIT por
--           linha pesa); o 3 e o 4 uma fração do 2.

-- 5. N+1 consultas: uma consulta por cliente, contra uma consulta só.
DECLARE
    v_inicio PLS_INTEGER := DBMS_UTILITY.GET_TIME;
    v_total  NUMBER;
    v_maior  NUMBER := 0;
BEGIN
    FOR c IN (SELECT id_cliente FROM tmp_perf_clientes) LOOP
        SELECT SUM(valor) INTO v_total FROM tmp_perf_pedidos WHERE id_cliente = c.id_cliente;
        v_maior := GREATEST(v_maior, v_total);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('5a. 2000 consultas: maior total ' || v_maior || ' em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');

    v_inicio := DBMS_UTILITY.GET_TIME;
    SELECT MAX(total) INTO v_maior
      FROM (SELECT SUM(valor) AS total FROM tmp_perf_pedidos GROUP BY id_cliente);
    DBMS_OUTPUT.PUT_LINE('5b. 1 consulta:     maior total ' || v_maior || ' em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
END;
/
-- Esperado: o mesmo maior total nas duas; a consulta única bem mais rápida

-- 6. Function com SELECT chamada no SELECT de uma consulta grande.
CREATE OR REPLACE FUNCTION tmp_fn_segmento (p_id_cliente IN NUMBER) RETURN VARCHAR2 IS
    v tmp_perf_clientes.segmento%TYPE;
BEGIN
    SELECT segmento INTO v FROM tmp_perf_clientes WHERE id_cliente = p_id_cliente;
    RETURN v;
END tmp_fn_segmento;
/

DECLARE
    v_inicio PLS_INTEGER;
    v_qtd    NUMBER;
BEGIN
    v_inicio := DBMS_UTILITY.GET_TIME;
    SELECT COUNT(*) INTO v_qtd FROM tmp_perf_pedidos WHERE tmp_fn_segmento(id_cliente) = 'ATACADO';
    DBMS_OUTPUT.PUT_LINE('6a. function por linha (200 mil chamadas): ' || v_qtd || ' em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');

    v_inicio := DBMS_UTILITY.GET_TIME;
    SELECT COUNT(*) INTO v_qtd FROM tmp_perf_pedidos WHERE (SELECT tmp_fn_segmento(id_cliente) FROM dual) = 'ATACADO';
    DBMS_OUTPUT.PUT_LINE('6b. subconsulta escalar (cache por valor): ' || v_qtd || ' em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');

    v_inicio := DBMS_UTILITY.GET_TIME;
    SELECT COUNT(*) INTO v_qtd
      FROM tmp_perf_pedidos p
      JOIN tmp_perf_clientes c ON c.id_cliente = p.id_cliente
     WHERE c.segmento = 'ATACADO';
    DBMS_OUTPUT.PUT_LINE('6c. JOIN:                                  ' || v_qtd || ' em '
        || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
END;
/
-- Esperado: 10000 nas três; 6a o mais lento, 6c o mais rápido. O ganho de 6b depende
--           de quantos valores distintos cabem no cache (2000 clientes: ganho parcial)

-- 7. O sinal em V$SQL: instrução barata com execuções demais.
COLUMN sql_text FORMAT A60 TRUNCATED
-- Esperado: no topo, o SELECT da function (200 mil execuções ou mais) e os UPDATEs
--           linha a linha (20 mil cada)
SELECT executions, ROUND(elapsed_time / 1e6, 2) AS segundos, sql_text
  FROM v$sql
 WHERE parsing_schema_name = USER
   AND executions > 1000
 ORDER BY executions DESC
 FETCH FIRST 5 ROWS ONLY;

DROP FUNCTION tmp_fn_segmento;
