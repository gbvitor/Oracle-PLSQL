-- =============================================================================
-- Tópico : Laços — LOOP, WHILE, FOR, EXIT, CONTINUE, rótulos
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. LOOP com EXIT WHEN: parcelas até quitar um valor.
DECLARE
    v_saldo   NUMBER := 1000;
    v_parcela NUMBER := 300;
    v_numero  PLS_INTEGER := 0;
BEGIN
    LOOP
        v_numero := v_numero + 1;
        v_saldo  := v_saldo - LEAST(v_parcela, v_saldo);
        DBMS_OUTPUT.PUT_LINE('Parcela ' || v_numero || ' -> saldo ' || v_saldo);
        EXIT WHEN v_saldo = 0;
    END LOOP;
END;
/
-- Esperado: 4 parcelas; saldos 700, 400, 100, 0

-- 2. WHILE: testa antes; com condição falsa de saída, não executa nenhuma vez.
DECLARE
    v_n PLS_INTEGER := 10;
BEGIN
    WHILE v_n < 5 LOOP
        DBMS_OUTPUT.PUT_LINE('nunca aparece');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('WHILE com condicao falsa: zero voltas');
END;
/
-- Esperado: WHILE com condicao falsa: zero voltas

-- 3. FOR numérico, REVERSE e limites invertidos.
BEGIN
    FOR i IN 1 .. 3 LOOP
        DBMS_OUTPUT.PUT('[' || i || ']');
    END LOOP;
    DBMS_OUTPUT.NEW_LINE;

    FOR i IN REVERSE 1 .. 3 LOOP
        DBMS_OUTPUT.PUT('[' || i || ']');
    END LOOP;
    DBMS_OUTPUT.NEW_LINE;

    FOR i IN 3 .. 1 LOOP
        DBMS_OUTPUT.PUT('[nunca]');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('3 .. 1 sem REVERSE: zero voltas');
END;
/
-- Esperado:
--   [1][2][3]
--   [3][2][1]
--   3 .. 1 sem REVERSE: zero voltas

-- 4. A variável do FOR não pode ser alterada.
BEGIN
    FOR i IN 1 .. 3 LOOP
        i := i + 1;
    END LOOP;
END;
/
-- Esperado: PLS-00363 (a expressão 'I' não pode ser usada como destino de atribuição)

-- 5. Os limites são avaliados uma vez.
DECLARE
    v_limite PLS_INTEGER := 3;
    v_voltas PLS_INTEGER := 0;
BEGIN
    FOR i IN 1 .. v_limite LOOP
        v_limite := 100;
        v_voltas := v_voltas + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Voltas: ' || v_voltas);
END;
/
-- Esperado: Voltas: 3

-- 6. CONTINUE: pular os pedidos cancelados.
BEGIN
    FOR r IN (SELECT id_pedido, status FROM pedidos WHERE id_cliente = 8 ORDER BY id_pedido) LOOP
        CONTINUE WHEN r.status = 'CANCELADO';
        DBMS_OUTPUT.PUT_LINE('Processado: ' || r.id_pedido);
    END LOOP;
END;
/
-- Esperado: Processado: 1018 (o 1007, cancelado, foi pulado)

-- 7. Rótulos: sair do laço externo de dentro do interno.
DECLARE
    v_ultimo VARCHAR2(20);
BEGIN
    <<externo>>
    FOR i IN 1 .. 10 LOOP
        FOR j IN 1 .. 10 LOOP
            EXIT externo WHEN i * j > 20;
            v_ultimo := i || ' x ' || j;
        END LOOP;
    END LOOP externo;
    DBMS_OUTPUT.PUT_LINE('Ultimo par antes de passar de 20: ' || v_ultimo);
END;
/
-- Esperado: Ultimo par antes de passar de 20: 3 x 6
--           (i = 1 e 2 percorrem j até 10; em i = 3, j = 7 dá 21 e sai dos dois laços)

-- 8. Laço linha a linha versus uma instrução SQL: mesmo resultado.
CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

-- Linha a linha (lento em volume).
BEGIN
    FOR r IN (SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 5) LOOP
        UPDATE tmp_produtos
           SET preco_unitario = ROUND(r.preco_unitario * 1.03, 2)
         WHERE id_produto = r.id_produto;
    END LOOP;
END;
/

ROLLBACK;

-- Uma instrução (rápido).
UPDATE tmp_produtos SET preco_unitario = ROUND(preco_unitario * 1.03, 2) WHERE id_categoria = 5;

-- Esperado: 8 -> 33.48 | 9 -> 46.35 | 10 -> 28.63
SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 5 ORDER BY id_produto;

ROLLBACK;
DROP TABLE tmp_produtos PURGE;
