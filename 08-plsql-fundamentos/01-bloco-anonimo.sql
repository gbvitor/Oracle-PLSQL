-- =============================================================================
-- Tópico : Bloco anônimo e DBMS_OUTPUT
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Os resultados esperados estão no comentário logo depois de cada bloco.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. O menor bloco possível.
BEGIN
    NULL;
END;
/
-- Esperado: "Procedimento PL/SQL concluído com sucesso." e nenhuma saída

-- 2. As três seções.
DECLARE
    v_total NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total FROM clientes;
    DBMS_OUTPUT.PUT_LINE('Clientes cadastrados: ' || v_total);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro: ' || SQLERRM);
END;
/
-- Esperado: Clientes cadastrados: 12

-- 3. PUT, PUT_LINE e NEW_LINE.
BEGIN
    DBMS_OUTPUT.PUT('A');
    DBMS_OUTPUT.PUT('B');
    DBMS_OUTPUT.NEW_LINE;
    DBMS_OUTPUT.PUT_LINE('C');
END;
/
-- Esperado:
--   AB
--   C

-- 4. A saída só aparece no fim do bloco.
--    DBMS_SESSION.SLEEP pausa 3 segundos; as duas linhas aparecem juntas no fim.
BEGIN
    DBMS_OUTPUT.PUT_LINE('Inicio: ' || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS'));
    DBMS_SESSION.SLEEP(3);
    DBMS_OUTPUT.PUT_LINE('Fim:    ' || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS'));
END;
/
-- Esperado: as duas linhas surgem ao mesmo tempo, com 3 segundos de diferença entre os horários

-- 5. BOOLEAN não vai direto para o PUT_LINE (antes do 23ai).
DECLARE
    v_tem_pedido BOOLEAN := TRUE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Tem pedido: ' || CASE WHEN v_tem_pedido THEN 'TRUE' ELSE 'FALSE' END);
END;
/
-- Esperado: Tem pedido: TRUE

-- 6. Bloco aninhado: declarações próprias e tratamento próprio de erro.
DECLARE
    v_externa VARCHAR2(20) := 'externa';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Fora: ' || v_externa);

    DECLARE
        v_interna VARCHAR2(20) := 'interna';
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Dentro: ' || v_externa || ' e ' || v_interna);
    END;

    DBMS_OUTPUT.PUT_LINE('Fora de novo');
END;
/
-- Esperado:
--   Fora: externa
--   Dentro: externa e interna
--   Fora de novo

-- 7. Relatório simples no DBMS_OUTPUT: pedidos por status.
BEGIN
    FOR r IN (SELECT status, COUNT(*) AS qtd FROM pedidos GROUP BY status ORDER BY status) LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(r.status, 12) || LPAD(r.qtd, 4));
    END LOOP;
END;
/
-- Esperado:
--   ABERTO         3
--   CANCELADO      1
--   ENTREGUE      17
--   FATURADO       3
