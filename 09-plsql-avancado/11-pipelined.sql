-- =============================================================================
-- Tópico : Pipelined table functions — gerador, split, transformação de cursor,
--          NO_DATA_NEEDED
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE TYPE, CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE OR REPLACE TYPE tmp_t_datas AS TABLE OF DATE;
/

CREATE OR REPLACE TYPE tmp_t_textos AS TABLE OF VARCHAR2(4000);
/

CREATE OR REPLACE TYPE tmp_t_item_liq AS OBJECT (
    id_pedido NUMBER,
    nr_item   NUMBER,
    valor     NUMBER,
    faixa     VARCHAR2(10)
);
/

CREATE OR REPLACE TYPE tmp_t_itens_liq AS TABLE OF tmp_t_item_liq;
/

-- 1. Gerador de meses e lacunas: meses sem nenhum pedido.
CREATE OR REPLACE FUNCTION tmp_fn_meses (p_inicio IN DATE, p_qtd IN PLS_INTEGER)
    RETURN tmp_t_datas PIPELINED
IS
BEGIN
    FOR i IN 0 .. p_qtd - 1 LOOP
        PIPE ROW (ADD_MONTHS(TRUNC(p_inicio, 'MM'), i));
    END LOOP;
    RETURN;
END tmp_fn_meses;
/

-- Esperado: 24
SELECT COUNT(*) FROM TABLE(tmp_fn_meses(DATE '2025-01-01', 24));

-- Esperado: 2026-03 | 2026-05 | 2026-07 | 2026-11 | 2026-12
SELECT TO_CHAR(m.column_value, 'YYYY-MM') AS mes
  FROM TABLE(tmp_fn_meses(DATE '2025-01-01', 24)) m
  LEFT JOIN pedidos p
    ON TRUNC(p.data_pedido, 'MM') = m.column_value
 GROUP BY m.column_value
HAVING COUNT(p.id_pedido) = 0
 ORDER BY m.column_value;

-- 2. Quebrar texto em linhas, preservando posições vazias.
CREATE OR REPLACE FUNCTION tmp_fn_split (p_texto IN VARCHAR2, p_sep IN VARCHAR2 DEFAULT ',')
    RETURN tmp_t_textos PIPELINED
IS
    v_inicio PLS_INTEGER := 1;
    v_pos    PLS_INTEGER;
BEGIN
    IF p_texto IS NULL THEN
        RETURN;
    END IF;

    LOOP
        v_pos := INSTR(p_texto, p_sep, v_inicio);
        IF v_pos = 0 THEN
            PIPE ROW (SUBSTR(p_texto, v_inicio));
            EXIT;
        END IF;
        PIPE ROW (SUBSTR(p_texto, v_inicio, v_pos - v_inicio));
        v_inicio := v_pos + LENGTH(p_sep);
    END LOOP;
    RETURN;
END tmp_fn_split;
/

-- Esperado: 1 SP | 2 MG | 3 (nulo) | 4 TO
SELECT ROWNUM AS pos, column_value AS item FROM TABLE(tmp_fn_split('SP,MG,,TO'));

-- Lista vinda de parâmetro de tela, usada como filtro.
-- Esperado: 5 clientes (3 de SP, 1 de MG, 1 de TO)
SELECT id_cliente, nome, uf
  FROM clientes
 WHERE uf IN (SELECT column_value FROM TABLE(tmp_fn_split('SP,MG,TO')))
 ORDER BY uf, id_cliente;

-- 3. Transformação: recebe um cursor, aplica regra por linha, devolve linhas novas.
CREATE OR REPLACE FUNCTION tmp_fn_itens_liquidos (p_rc IN SYS_REFCURSOR)
    RETURN tmp_t_itens_liq PIPELINED
IS
    r     itens_pedido%ROWTYPE;
    v_val NUMBER;
BEGIN
    LOOP
        FETCH p_rc INTO r;
        EXIT WHEN p_rc%NOTFOUND;

        v_val := ROUND(r.quantidade * r.preco_unitario * (1 - r.pct_desconto / 100), 2);

        PIPE ROW (tmp_t_item_liq(
            r.id_pedido,
            r.nr_item,
            v_val,
            CASE WHEN v_val >= 1000 THEN 'ALTO' ELSE 'NORMAL' END));
    END LOOP;
    CLOSE p_rc;
    RETURN;
END tmp_fn_itens_liquidos;
/

-- Esperado: 1001 1 598 NORMAL | 1001 2 210 NORMAL | 1001 3 237.5 NORMAL
--           1002 1 8089.2 ALTO | 1002 2 3348 ALTO | 1002 3 4839.3 ALTO
SELECT *
  FROM TABLE(tmp_fn_itens_liquidos(CURSOR(SELECT *
                                            FROM itens_pedido
                                           WHERE id_pedido IN (1001, 1002)
                                           ORDER BY id_pedido, nr_item)));

-- A saída é uma tabela como outra qualquer: agregável.
-- Esperado: 122815.43 (o total geral, agora calculado pela function)
SELECT SUM(valor) FROM TABLE(tmp_fn_itens_liquidos(CURSOR(SELECT * FROM itens_pedido)));

-- 4. Consumidor que para antes: NO_DATA_NEEDED.
CREATE OR REPLACE FUNCTION tmp_fn_sequencia (p_max IN PLS_INTEGER)
    RETURN tmp_t_textos PIPELINED
IS
    v_gerados PLS_INTEGER := 0;
BEGIN
    FOR i IN 1 .. p_max LOOP
        PIPE ROW ('linha ' || i);
        v_gerados := i;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('[function terminou: gerou ' || v_gerados || ']');
    RETURN;
EXCEPTION
    WHEN NO_DATA_NEEDED THEN
        DBMS_OUTPUT.PUT_LINE('[consumidor parou depois de ' || v_gerados || ' linhas]');
        RAISE;
END tmp_fn_sequencia;
/

-- Esperado: 3 linhas e "[consumidor parou depois de N linhas]", com N pequeno
--           (pode passar de 3: as linhas chegam ao SQL em lotes), e não 1 milhão
SELECT column_value FROM TABLE(tmp_fn_sequencia(1000000)) FETCH FIRST 3 ROWS ONLY;

-- Esperado: 5 linhas e "[function terminou: gerou 5]"
SELECT column_value FROM TABLE(tmp_fn_sequencia(5));

-- 5. Estimativa do otimizador: número fixo, não o real.
EXPLAIN PLAN FOR SELECT * FROM TABLE(tmp_fn_meses(DATE '2025-01-01', 24));

-- Esperado: COLLECTION ITERATOR PICKLER FETCH com Rows estimadas num valor fixo
--           (costuma ser 8168 em bloco de 8 KB), embora a function devolva 24
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +ROWS'));

-- Informar a cardinalidade com hint.
EXPLAIN PLAN FOR SELECT /*+ CARDINALITY(m 24) */ * FROM TABLE(tmp_fn_meses(DATE '2025-01-01', 24)) m;

-- Esperado: Rows 24
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +ROWS'));

DROP FUNCTION tmp_fn_sequencia;
DROP FUNCTION tmp_fn_itens_liquidos;
DROP FUNCTION tmp_fn_split;
DROP FUNCTION tmp_fn_meses;
DROP TYPE tmp_t_itens_liq;
DROP TYPE tmp_t_item_liq;
DROP TYPE tmp_t_textos;
DROP TYPE tmp_t_datas;
