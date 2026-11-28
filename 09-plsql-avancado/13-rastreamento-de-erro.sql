-- =============================================================================
-- Tópico : Rastreamento de erro — FORMAT_ERROR_STACK, FORMAT_ERROR_BACKTRACE,
--          FORMAT_CALL_STACK, UTL_CALL_STACK, $$PLSQL_UNIT e $$PLSQL_LINE
-- Seção  : 09-plsql-avancado
-- Versão : 19c (UTL_CALL_STACK exige 12c+)
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- Package com três níveis: a chama b, b chama c, c divide por zero.
CREATE OR REPLACE PACKAGE tmp_pkg_rastreio IS
    PROCEDURE a;
    PROCEDURE a_com_relancamento;
    PROCEDURE mostrar_chamadas;
END tmp_pkg_rastreio;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_rastreio IS

    PROCEDURE c IS
        v_zero PLS_INTEGER := 0;
        v_num  NUMBER;
    BEGIN
        v_num := 1 / v_zero;
    END c;

    PROCEDURE b IS
    BEGIN
        c;
    END b;

    PROCEDURE b_que_relanca IS
    BEGIN
        c;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END b_que_relanca;

    PROCEDURE a IS
    BEGIN
        b;
    END a;

    PROCEDURE a_com_relancamento IS
    BEGIN
        b_que_relanca;
    END a_com_relancamento;

    PROCEDURE nivel_3 IS
        v_nome  VARCHAR2(200);
        v_linha PLS_INTEGER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Profundidade: ' || UTL_CALL_STACK.DYNAMIC_DEPTH);
        FOR i IN 1 .. UTL_CALL_STACK.DYNAMIC_DEPTH LOOP
            v_nome  := UTL_CALL_STACK.CONCATENATE_SUBPROGRAM(UTL_CALL_STACK.SUBPROGRAM(i));
            v_linha := UTL_CALL_STACK.UNIT_LINE(i);
            DBMS_OUTPUT.PUT_LINE('  ' || i || ': ' || v_nome || ' linha ' || v_linha);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('$$PLSQL_UNIT = ' || $$PLSQL_UNIT || ' | $$PLSQL_LINE = ' || $$PLSQL_LINE);
    END nivel_3;

    PROCEDURE nivel_2 IS
    BEGIN
        nivel_3;
    END nivel_2;

    PROCEDURE mostrar_chamadas IS
    BEGIN
        nivel_2;
    END mostrar_chamadas;

END tmp_pkg_rastreio;
/

-- 1. SQLERRM e FORMAT_ERROR_STACK dizem o quê; o backtrace diz onde.
BEGIN
    tmp_pkg_rastreio.a;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SQLERRM:   ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Backtrace:');
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/
-- Esperado:
--   SQLERRM:   ORA-01476: o divisor é igual a zero
--   Backtrace:
--   ORA-06512: em "ESTUDO.TMP_PKG_RASTREIO", line 7     <- c: a divisão
--   ORA-06512: em "ESTUDO.TMP_PKG_RASTREIO", line 12    <- b chamando c
--   ORA-06512: em "ESTUDO.TMP_PKG_RASTREIO", line 25    <- a chamando b
--   ORA-06512: em line 2                                <- o bloco anônimo
--   (linhas contadas a partir do CREATE OR REPLACE PACKAGE BODY)

-- 2. Com RAISE num tratador intermediário, o backtrace aponta para o RAISE.
BEGIN
    tmp_pkg_rastreio.a_com_relancamento;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/
-- Esperado: a primeira linha do backtrace aponta para a linha 20 (o RAISE em
--           b_que_relanca), e não para a linha 7, onde o erro nasceu.
--           Por isso o registro deve ser feito no primeiro tratador.

-- 3. UTL_CALL_STACK: o backtrace item a item, sem analisar texto.
BEGIN
    tmp_pkg_rastreio.a;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erros na pilha: ' || UTL_CALL_STACK.ERROR_DEPTH);
        FOR i IN 1 .. UTL_CALL_STACK.ERROR_DEPTH LOOP
            DBMS_OUTPUT.PUT_LINE('  erro ' || i || ': ORA-'
                || LPAD(UTL_CALL_STACK.ERROR_NUMBER(i), 5, '0') || ' ' || UTL_CALL_STACK.ERROR_MSG(i));
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('Níveis do backtrace: ' || UTL_CALL_STACK.BACKTRACE_DEPTH);
        FOR i IN 1 .. UTL_CALL_STACK.BACKTRACE_DEPTH LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || i || ': '
                || NVL(UTL_CALL_STACK.BACKTRACE_UNIT(i), '(bloco anônimo)')
                || ' linha ' || UTL_CALL_STACK.BACKTRACE_LINE(i));
        END LOOP;
END;
/
-- Esperado:
--   Erros na pilha: 1
--     erro 1: ORA-01476 o divisor é igual a zero
--   Níveis do backtrace: 4
--   e as quatro linhas 7, 12, 25 e 2, numa das duas ordens: compare com o passo 1
--   para saber qual índice traz a origem (linha 7) na sua versão.

-- 4. UTL_CALL_STACK fora de erro: quem chamou quem, com o nome da rotina interna.
EXEC tmp_pkg_rastreio.mostrar_chamadas
-- Esperado:
--   Profundidade: 4
--     1: TMP_PKG_RASTREIO.NIVEL_3 linha 40
--     2: TMP_PKG_RASTREIO.NIVEL_2 linha 48
--     3: TMP_PKG_RASTREIO.MOSTRAR_CHAMADAS linha 53
--     4: __anonymous_block linha 1
--   $$PLSQL_UNIT = TMP_PKG_RASTREIO | $$PLSQL_LINE = 43
--   (linhas contadas a partir do CREATE OR REPLACE PACKAGE BODY)

-- 5. A versão em texto, para comparar: FORMAT_CALL_STACK mostra só package e linha.
BEGIN
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_CALL_STACK);
END;
/
-- Esperado: cabeçalho "----- PL/SQL Call Stack -----" e uma linha por nível
--           (object handle, line number, object name)

DROP PACKAGE tmp_pkg_rastreio;
