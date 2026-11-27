-- =============================================================================
-- Tópico : Coleções — associative array, nested table, VARRAY, métodos,
--          erros típicos e coleções em SQL
-- Seção  : 09-plsql-avancado
-- Versão : 19c (passo 6 exige 18c+)
-- Requer : schema de exemplo (00-ambiente); CREATE TYPE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Associative array indexado por texto: contar clientes por UF.
--    Percorrido em ordem de chave, sem ORDER BY.
DECLARE
    TYPE t_contagem IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(2);
    v_por_uf t_contagem;
    v_uf     VARCHAR2(2);
BEGIN
    FOR r IN (SELECT uf FROM clientes) LOOP
        IF v_por_uf.EXISTS(r.uf) THEN
            v_por_uf(r.uf) := v_por_uf(r.uf) + 1;
        ELSE
            v_por_uf(r.uf) := 1;
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('UFs distintas: ' || v_por_uf.COUNT);

    v_uf := v_por_uf.FIRST;
    WHILE v_uf IS NOT NULL LOOP
        DBMS_OUTPUT.PUT_LINE(v_uf || ' ' || v_por_uf(v_uf));
        v_uf := v_por_uf.NEXT(v_uf);
    END LOOP;
END;
/
-- Esperado: UFs distintas: 10
--   BA 1 | CE 1 | DF 1 | GO 1 | MG 1 | PE 1 | PR 1 | RS 1 | SP 3 | TO 1

-- 2. Associative array indexado por inteiro: cache de nomes de produto.
--    Índice = chave da tabela; buracos são normais.
DECLARE
    TYPE t_nomes IS TABLE OF produtos.nome%TYPE INDEX BY PLS_INTEGER;
    v_nomes t_nomes;
BEGIN
    FOR r IN (SELECT id_produto, nome FROM produtos) LOOP
        v_nomes(r.id_produto) := r.nome;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Produto 13: ' || v_nomes(13));
    DBMS_OUTPUT.PUT_LINE('FIRST ' || v_nomes.FIRST || ' | LAST ' || v_nomes.LAST || ' | COUNT ' || v_nomes.COUNT);
    DBMS_OUTPUT.PUT_LINE('Existe o 99? ' || CASE WHEN v_nomes.EXISTS(99) THEN 'sim' ELSE 'não' END);

    DBMS_OUTPUT.PUT_LINE(v_nomes(99));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Ler o 99 sem EXISTS: NO_DATA_FOUND');
END;
/
-- Esperado:
--   Produto 13: Cadeira giratoria
--   FIRST 1 | LAST 15 | COUNT 15
--   Existe o 99? não
--   Ler o 99 sem EXISTS: NO_DATA_FOUND

-- 3. Nested table: construtor, EXTEND, DELETE e coleção esparsa.
DECLARE
    TYPE t_ids IS TABLE OF NUMBER;
    v_ids t_ids := t_ids(1001, 1006, 1015);
    v_i   PLS_INTEGER;
BEGIN
    v_ids.EXTEND;
    v_ids(v_ids.LAST) := 1022;
    DBMS_OUTPUT.PUT_LINE('Depois do EXTEND: COUNT ' || v_ids.COUNT);

    v_ids.DELETE(2);
    DBMS_OUTPUT.PUT_LINE('Depois do DELETE(2): COUNT ' || v_ids.COUNT || ' | LAST ' || v_ids.LAST);

    v_i := v_ids.FIRST;
    WHILE v_i IS NOT NULL LOOP
        DBMS_OUTPUT.PUT_LINE('  [' || v_i || '] ' || v_ids(v_i));
        v_i := v_ids.NEXT(v_i);
    END LOOP;

    FOR i IN 1 .. v_ids.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('  FOR 1..COUNT [' || i || '] ' || v_ids(i));
    END LOOP;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('FOR 1..COUNT na coleção esparsa: NO_DATA_FOUND no índice 2');
END;
/
-- Esperado:
--   Depois do EXTEND: COUNT 4
--   Depois do DELETE(2): COUNT 3 | LAST 4
--     [1] 1001
--     [3] 1015
--     [4] 1022
--     FOR 1..COUNT [1] 1001
--   FOR 1..COUNT na coleção esparsa: NO_DATA_FOUND no índice 2

-- 4. Erros de nested table e VARRAY.
DECLARE
    TYPE t_ids IS TABLE OF NUMBER;
    v_ids t_ids;
BEGIN
    v_ids(1) := 10;
EXCEPTION
    WHEN COLLECTION_IS_NULL THEN
        DBMS_OUTPUT.PUT_LINE('Sem construtor: COLLECTION_IS_NULL (' || SQLCODE || ')');
END;
/
-- Esperado: Sem construtor: COLLECTION_IS_NULL (-6531)

DECLARE
    TYPE t_ids IS TABLE OF NUMBER;
    v_ids t_ids := t_ids();
BEGIN
    v_ids(1) := 10;
EXCEPTION
    WHEN SUBSCRIPT_BEYOND_COUNT THEN
        DBMS_OUTPUT.PUT_LINE('Sem EXTEND: SUBSCRIPT_BEYOND_COUNT (' || SQLCODE || ')');
END;
/
-- Esperado: Sem EXTEND: SUBSCRIPT_BEYOND_COUNT (-6533)

DECLARE
    TYPE t_status IS VARRAY(3) OF VARCHAR2(12);
    v_status t_status := t_status('ABERTO', 'FATURADO', 'ENTREGUE');
BEGIN
    DBMS_OUTPUT.PUT_LINE('LIMIT ' || v_status.LIMIT || ' | COUNT ' || v_status.COUNT);
    v_status.EXTEND;
EXCEPTION
    WHEN SUBSCRIPT_OUTSIDE_LIMIT THEN
        DBMS_OUTPUT.PUT_LINE('EXTEND além do limite: SUBSCRIPT_OUTSIDE_LIMIT (' || SQLCODE || ')');
END;
/
-- Esperado: LIMIT 3 | COUNT 3 | EXTEND além do limite: SUBSCRIPT_OUTSIDE_LIMIT (-6532)

-- 5. FOR FIRST .. LAST em coleção vazia: VALUE_ERROR. 1 .. COUNT: zero voltas.
DECLARE
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_vazia t_ids;
BEGIN
    FOR i IN 1 .. v_vazia.COUNT LOOP
        NULL;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('1 .. COUNT: ok');

    FOR i IN v_vazia.FIRST .. v_vazia.LAST LOOP
        NULL;
    END LOOP;
EXCEPTION
    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE('FIRST .. LAST em coleção vazia: VALUE_ERROR');
END;
/
-- Esperado: 1 .. COUNT: ok | FIRST .. LAST em coleção vazia: VALUE_ERROR

-- 6. [18c+] Expressão qualificada para associative array.
DECLARE
    TYPE t_mapa IS TABLE OF VARCHAR2(30) INDEX BY VARCHAR2(12);
    v_rotulo t_mapa := t_mapa('ABERTO'    => 'Em digitação',
                              'FATURADO'  => 'Nota emitida',
                              'ENTREGUE'  => 'Concluído',
                              'CANCELADO' => 'Cancelado');
BEGIN
    FOR r IN (SELECT id_pedido, status FROM pedidos WHERE id_cliente = 10 ORDER BY id_pedido) LOOP
        DBMS_OUTPUT.PUT_LINE(r.id_pedido || ' ' || v_rotulo(r.status));
    END LOOP;
END;
/
-- Esperado: 1008 Concluído | 1014 Concluído | 1020 Nota emitida

-- 7. Nested table como tipo SQL: lista passada para dentro da consulta.
CREATE OR REPLACE TYPE tmp_t_ids AS TABLE OF NUMBER;
/

-- Esperado: 1001 1045.5 | 1008 27286 | 1013 2609.31
SELECT p.id_pedido,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.id_pedido IN (SELECT column_value FROM TABLE(tmp_t_ids(1001, 1008, 1013)))
 GROUP BY p.id_pedido
 ORDER BY p.id_pedido;

-- A mesma lista vinda de uma variável PL/SQL.
DECLARE
    v_ids tmp_t_ids := tmp_t_ids(1001, 1008, 1013);
    v_qtd PLS_INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_qtd FROM pedidos WHERE id_pedido MEMBER OF v_ids;
    DBMS_OUTPUT.PUT_LINE('Pedidos encontrados: ' || v_qtd);
END;
/
-- Esperado: Pedidos encontrados: 3

-- 8. Operadores de conjunto sobre nested tables.
DECLARE
    v_a tmp_t_ids := tmp_t_ids(1, 2, 3, 3);
    v_b tmp_t_ids := tmp_t_ids(3, 4);
    v_r tmp_t_ids;

    PROCEDURE mostrar (p_rotulo VARCHAR2, p_lista tmp_t_ids) IS
        v_txt VARCHAR2(200);
    BEGIN
        FOR i IN 1 .. p_lista.COUNT LOOP
            v_txt := v_txt || p_lista(i) || ' ';
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD(p_rotulo, 18) || v_txt);
    END;
BEGIN
    mostrar('UNION',           v_a MULTISET UNION v_b);
    mostrar('UNION DISTINCT',  v_a MULTISET UNION DISTINCT v_b);
    mostrar('INTERSECT',       v_a MULTISET INTERSECT v_b);
    mostrar('EXCEPT',          v_a MULTISET EXCEPT v_b);
    mostrar('SET(a)',          SET(v_a));
    DBMS_OUTPUT.PUT_LINE('CARDINALITY(a)    ' || CARDINALITY(v_a));
    DBMS_OUTPUT.PUT_LINE('a IS A SET?       ' || CASE WHEN v_a IS A SET THEN 'sim' ELSE 'não' END);
    DBMS_OUTPUT.PUT_LINE('4 MEMBER OF b?    ' || CASE WHEN 4 MEMBER OF v_b THEN 'sim' ELSE 'não' END);
END;
/
-- Esperado:
--   UNION             1 2 3 3 3 4
--   UNION DISTINCT    1 2 3 4
--   INTERSECT         3
--   EXCEPT            1 2 3
--   SET(a)            1 2 3
--   CARDINALITY(a)    4
--   a IS A SET?       não
--   4 MEMBER OF b?    sim
--   (MULTISET EXCEPT sem DISTINCT tira uma ocorrência do 3 para cada 3 em b)

DROP TYPE tmp_t_ids;
