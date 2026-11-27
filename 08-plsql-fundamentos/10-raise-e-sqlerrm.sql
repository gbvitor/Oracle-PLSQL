-- =============================================================================
-- Tópico : RAISE, RAISE_APPLICATION_ERROR, SQLCODE e SQLERRM
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. RAISE; relança o mesmo erro, com o código original.
DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    BEGIN
        v_num := 1 / v_zero;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Bloco interno registrou: ' || SQLCODE);
            RAISE;
    END;
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('Bloco externo recebeu ZERO_DIVIDE: ' || SQLCODE);
END;
/
-- Esperado: Bloco interno registrou: -1476 | Bloco externo recebeu ZERO_DIVIDE: -1476

-- 2. RAISE fora de tratador precisa de nome.
BEGIN
    RAISE;
END;
/
-- Esperado: erro de compilação PLS-00367 (RAISE sem nome só é permitido dentro de um tratador)

-- 3. RAISE_APPLICATION_ERROR sem tratamento: é o que o chamador vê.
DECLARE
    v_id_pedido pedidos.id_pedido%TYPE := 9999;
    v_qtd       PLS_INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_qtd FROM pedidos WHERE id_pedido = v_id_pedido;
    IF v_qtd = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Pedido ' || v_id_pedido || ' não encontrado');
    END IF;
END;
/
-- Esperado: ORA-20010: Pedido 9999 não encontrado
--           seguido de ORA-06512 indicando a linha

-- 4. Número fora da faixa -20000 a -20999.
BEGIN
    RAISE_APPLICATION_ERROR(-30000, 'fora da faixa');
END;
/
-- Esperado: ORA-21000 (número de erro fora da faixa para RAISE_APPLICATION_ERROR)

-- 5. Terceiro parâmetro: FALSE substitui a pilha, TRUE preserva a causa.
DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    BEGIN
        BEGIN
            v_num := 1 / v_zero;
        EXCEPTION
            WHEN ZERO_DIVIDE THEN
                RAISE_APPLICATION_ERROR(-20020, 'Falha ao calcular comissão');
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('--- manter_pilha = FALSE');
            DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
    END;

    BEGIN
        BEGIN
            v_num := 1 / v_zero;
        EXCEPTION
            WHEN ZERO_DIVIDE THEN
                RAISE_APPLICATION_ERROR(-20020, 'Falha ao calcular comissão', TRUE);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('--- manter_pilha = TRUE');
            DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
    END;
END;
/
-- Esperado:
--   --- manter_pilha = FALSE
--   ORA-20020: Falha ao calcular comissão
--   --- manter_pilha = TRUE
--   ORA-20020: Falha ao calcular comissão
--   ORA-01476: o divisor é igual a zero
--   (pode haver linhas ORA-06512 adicionais, conforme a versão)

-- 6. Valores de SQLCODE e SQLERRM em cada situação.
DECLARE
    e_regra EXCEPTION;
    v_nome  clientes.nome%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Sem erro:        ' || SQLCODE || ' | ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('SQLERRM(-1422):  ' || SQLERRM(-1422));

    BEGIN
        SELECT nome INTO v_nome FROM clientes WHERE id_cliente = 999;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('NO_DATA_FOUND:   ' || SQLCODE || ' | ' || SQLERRM);
    END;

    BEGIN
        RAISE e_regra;
    EXCEPTION
        WHEN e_regra THEN
            DBMS_OUTPUT.PUT_LINE('Do usuário:      ' || SQLCODE || ' | ' || SQLERRM);
    END;

    BEGIN
        RAISE_APPLICATION_ERROR(-20030, 'Regra de negócio');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Da aplicação:    ' || SQLCODE || ' | ' || SQLERRM);
    END;
END;
/
-- Esperado (textos conforme o idioma da sessão):
--   Sem erro:        0 | ORA-0000: normal, successful completion
--   SQLERRM(-1422):  ORA-01422: a extração exata retorna mais do que o número solicitado de linhas
--   NO_DATA_FOUND:   100 | ORA-01403: dados não encontrados
--   Do usuário:      1 | User-Defined Exception
--   Da aplicação:    -20030 | ORA-20030: Regra de negócio

-- 7. Tratar por nome um erro de aplicação com PRAGMA EXCEPTION_INIT.
DECLARE
    e_pedido_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_pedido_inexistente, -20010);

    PROCEDURE exigir_pedido(p_id NUMBER) IS
        v_qtd PLS_INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_qtd FROM pedidos WHERE id_pedido = p_id;
        IF v_qtd = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Pedido ' || p_id || ' não encontrado');
        END IF;
    END;
BEGIN
    exigir_pedido(1001);
    DBMS_OUTPUT.PUT_LINE('1001 existe');
    exigir_pedido(9999);
EXCEPTION
    WHEN e_pedido_inexistente THEN
        DBMS_OUTPUT.PUT_LINE('Tratado por nome: ' || SQLERRM);
END;
/
-- Esperado: 1001 existe | Tratado por nome: ORA-20010: Pedido 9999 não encontrado

-- 8. SQLCODE e SQLERRM não entram direto numa instrução SQL.
CREATE TABLE tmp_log_erro (
    momento  TIMESTAMP DEFAULT SYSTIMESTAMP,
    codigo   NUMBER,
    mensagem VARCHAR2(4000)
);

DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    v_num := 1 / v_zero;
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO tmp_log_erro (codigo, mensagem) VALUES (SQLCODE, SQLERRM);
END;
/
-- Esperado: erro de compilação; SQLCODE e SQLERRM não existem no SQL
--           (confira o código exato do erro na sua versão)

-- 9. Registrar e relançar: o log com INSERT comum some junto.
DECLARE
    v_zero     PLS_INTEGER := 0;
    v_num      NUMBER;
    v_codigo   NUMBER;
    v_mensagem VARCHAR2(4000);
BEGIN
    v_num := 1 / v_zero;
EXCEPTION
    WHEN OTHERS THEN
        v_codigo   := SQLCODE;
        v_mensagem := DBMS_UTILITY.FORMAT_ERROR_STACK || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        INSERT INTO tmp_log_erro (codigo, mensagem) VALUES (v_codigo, v_mensagem);
        RAISE;
END;
/
-- Esperado: ORA-01476 chega ao SQL*Plus

-- Esperado: 0. O INSERT do log foi desfeito junto com a chamada que falhou.
--           Para o log sobreviver: PRAGMA AUTONOMOUS_TRANSACTION (seção 09, tópico 12).
SELECT COUNT(*) FROM tmp_log_erro;

-- 10. O backtrace informa a linha; SQLERRM não.
DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    v_num := 1;
    v_num := 2;
    v_num := 3 / v_zero;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SQLERRM:   ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/
-- Esperado:
--   SQLERRM:   ORA-01476: o divisor é igual a zero
--   Backtrace: ORA-06512: em line 7
--   (linha 7 do bloco, contando a partir do DECLARE: a da divisão)

DROP TABLE tmp_log_erro PURGE;
