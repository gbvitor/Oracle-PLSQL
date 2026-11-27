-- =============================================================================
-- Tópico : IF, ELSIF, ELSE e CASE em PL/SQL
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. IF / ELSIF / ELSE: classificação do limite de crédito.
BEGIN
    FOR r IN (SELECT id_cliente, limite_credito FROM clientes WHERE id_cliente IN (4, 6, 7, 10)
              ORDER BY id_cliente) LOOP
        IF r.limite_credito >= 50000 THEN
            DBMS_OUTPUT.PUT_LINE(r.id_cliente || ': alto');
        ELSIF r.limite_credito >= 10000 THEN
            DBMS_OUTPUT.PUT_LINE(r.id_cliente || ': medio');
        ELSIF r.limite_credito IS NULL THEN
            DBMS_OUTPUT.PUT_LINE(r.id_cliente || ': nao analisado');
        ELSE
            DBMS_OUTPUT.PUT_LINE(r.id_cliente || ': baixo');
        END IF;
    END LOOP;
END;
/
-- Esperado:
--   4: baixo
--   6: medio
--   7: nao analisado
--   10: alto

-- 2. NULL cai no ELSE.
DECLARE
    v_valor NUMBER;
BEGIN
    IF v_valor <> 0 THEN
        DBMS_OUTPUT.PUT_LINE('diferente de zero');
    ELSE
        DBMS_OUTPUT.PUT_LINE('caiu no ELSE (o programador pensou em zero, mas e NULL)');
    END IF;
END;
/
-- Esperado: caiu no ELSE (...)

-- 3. Comando CASE sem ELSE: CASE_NOT_FOUND.
DECLARE
    v_status pedidos.status%TYPE := 'CANCELADO';
BEGIN
    CASE v_status
        WHEN 'ABERTO'   THEN DBMS_OUTPUT.PUT_LINE('em aberto');
        WHEN 'FATURADO' THEN DBMS_OUTPUT.PUT_LINE('faturado');
        WHEN 'ENTREGUE' THEN DBMS_OUTPUT.PUT_LINE('entregue');
    END CASE;
END;
/
-- Esperado: ORA-06592 (CASE não encontrado ao executar a instrução CASE)

-- Com ELSE: todos os casos considerados.
DECLARE
    v_status pedidos.status%TYPE := 'CANCELADO';
BEGIN
    CASE v_status
        WHEN 'ABERTO'   THEN DBMS_OUTPUT.PUT_LINE('em aberto');
        WHEN 'FATURADO' THEN DBMS_OUTPUT.PUT_LINE('faturado');
        WHEN 'ENTREGUE' THEN DBMS_OUTPUT.PUT_LINE('entregue');
        ELSE                 DBMS_OUTPUT.PUT_LINE('outro status: ' || v_status);
    END CASE;
END;
/
-- Esperado: outro status: CANCELADO

-- 4. CASE expressão sem ELSE: NULL, sem erro.
DECLARE
    v_status    pedidos.status%TYPE := 'CANCELADO';
    v_descricao VARCHAR2(30);
BEGIN
    v_descricao := CASE v_status WHEN 'ABERTO' THEN 'em aberto' END;
    DBMS_OUTPUT.PUT_LINE('[' || v_descricao || ']');
END;
/
-- Esperado: []

-- 5. CASE pesquisado como comando: faixa de valor de cada pedido.
BEGIN
    FOR r IN (SELECT p.id_pedido,
                     SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
                FROM pedidos p JOIN itens_pedido i ON i.id_pedido = p.id_pedido
               WHERE p.id_pedido IN (1005, 1013, 1008)
               GROUP BY p.id_pedido
               ORDER BY p.id_pedido) LOOP
        CASE
            WHEN r.valor >= 10000 THEN DBMS_OUTPUT.PUT_LINE(r.id_pedido || ' grande  ' || r.valor);
            WHEN r.valor >= 1000  THEN DBMS_OUTPUT.PUT_LINE(r.id_pedido || ' medio   ' || r.valor);
            ELSE                       DBMS_OUTPUT.PUT_LINE(r.id_pedido || ' pequeno ' || r.valor);
        END CASE;
    END LOOP;
END;
/
-- Esperado:
--   1005 pequeno 139.7
--   1008 grande  27286
--   1013 medio   2609.31

-- 6. Curto-circuito: a divisão não é avaliada quando o divisor é zero.
DECLARE
    v_total   NUMBER := 100;
    v_divisor NUMBER := 0;
BEGIN
    IF v_divisor <> 0 AND v_total / v_divisor > 10 THEN
        DBMS_OUTPUT.PUT_LINE('media acima de 10');
    ELSE
        DBMS_OUTPUT.PUT_LINE('sem divisao por zero: o AND parou na primeira condicao');
    END IF;
END;
/
-- Esperado: sem divisao por zero: (...)
