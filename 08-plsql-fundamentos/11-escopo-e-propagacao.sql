-- =============================================================================
-- Tópico : Escopo, blocos aninhados e propagação de exceções
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Visibilidade, nome escondido e qualificação por rótulo.
--    O rótulo fica dentro de um BEGIN externo: o SQL*Plus reconhece o início
--    de um bloco PL/SQL por DECLARE ou BEGIN.
BEGIN
    <<externo>>
    DECLARE
        v_total NUMBER := 100;
        v_uf    CHAR(2) := 'SP';
    BEGIN
        DECLARE
            v_total NUMBER := 1;
        BEGIN
            DBMS_OUTPUT.PUT_LINE('Interno v_total: ' || v_total);
            DBMS_OUTPUT.PUT_LINE('Externo pelo rótulo: ' || externo.v_total);
            DBMS_OUTPUT.PUT_LINE('Do externo, sem conflito: ' || v_uf);
        END;
        DBMS_OUTPUT.PUT_LINE('Fora do interno v_total: ' || v_total);
    END externo;
END;
/
-- Esperado: Interno 1 | Externo pelo rótulo 100 | SP | Fora do interno 100

-- 2. Variável com nome de coluna: dentro do SQL, a coluna vence.
CREATE TABLE tmp_clientes AS SELECT * FROM clientes;

DECLARE
    id_cliente NUMBER := 5;
BEGIN
    DELETE FROM tmp_clientes WHERE id_cliente = id_cliente;
    DBMS_OUTPUT.PUT_LINE('Linhas excluídas: ' || SQL%ROWCOUNT);
END;
/
-- Esperado: Linhas excluídas: 12 (a tabela inteira, não só o cliente 5)

ROLLBACK;

DECLARE
    v_id_cliente NUMBER := 5;
BEGIN
    DELETE FROM tmp_clientes WHERE id_cliente = v_id_cliente;
    DBMS_OUTPUT.PUT_LINE('Linhas excluídas: ' || SQL%ROWCOUNT);
END;
/
-- Esperado: Linhas excluídas: 1

ROLLBACK;

-- 3. Erro tratado no bloco interno: o externo segue normalmente.
DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('A');
    BEGIN
        v_num := 1 / v_zero;
        DBMS_OUTPUT.PUT_LINE('B (pulado)');
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            DBMS_OUTPUT.PUT_LINE('C (tratado no interno)');
    END;
    DBMS_OUTPUT.PUT_LINE('D');
END;
/
-- Esperado: A | C (tratado no interno) | D

-- 4. Erro sem tratamento no interno: sobe e o resto do externo é pulado.
DECLARE
    v_nome clientes.nome%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('A');
    BEGIN
        SELECT nome INTO v_nome FROM clientes WHERE id_cliente = 999;
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('não corresponde');
    END;
    DBMS_OUTPUT.PUT_LINE('D (pulado)');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('E (tratado no externo)');
END;
/
-- Esperado: A | E (tratado no externo)

-- 5. Erro na seção DECLARE: o tratador do próprio bloco não pega.
BEGIN
    DECLARE
        v_uf CHAR(2) := 'Tocantins';
    BEGIN
        DBMS_OUTPUT.PUT_LINE('não chega aqui');
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('tratador do bloco interno');
    END;
EXCEPTION
    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE('tratador do bloco EXTERNO: o erro foi na inicialização');
END;
/
-- Esperado: tratador do bloco EXTERNO: o erro foi na inicialização

-- 6. Erro dentro de um tratador: os outros WHEN do mesmo bloco não pegam.
BEGIN
    DECLARE
        v_zero PLS_INTEGER := 0;
        v_num  NUMBER;
    BEGIN
        v_num := 1 / v_zero;
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            v_num := TO_NUMBER('abc');
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('irmão: não pega');
    END;
EXCEPTION
    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE('externo pegou o erro do tratador: ' || SQLCODE);
END;
/
-- Esperado: externo pegou o erro do tratador: -6502

-- 7. Exceção do usuário fora do bloco onde foi declarada.
BEGIN
    DECLARE
        e_interna EXCEPTION;
    BEGIN
        RAISE e_interna;
    END;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Só OTHERS alcança: SQLCODE ' || SQLCODE || ' | ' || SQLERRM);
END;
/
-- Esperado: Só OTHERS alcança: SQLCODE 1 | User-Defined Exception

-- 8. Continuar o laço apesar do erro: bloco com tratador dentro do laço.
DECLARE
    v_resultado NUMBER;
BEGIN
    FOR i IN 1 .. 5 LOOP
        BEGIN
            v_resultado := 10 / (i - 3);
            DBMS_OUTPUT.PUT_LINE('i = ' || i || ': ' || v_resultado);
        EXCEPTION
            WHEN ZERO_DIVIDE THEN
                DBMS_OUTPUT.PUT_LINE('i = ' || i || ': erro registrado, segue');
        END;
    END LOOP;
END;
/
-- Esperado: i = 1: -5 | i = 2: -10 | i = 3: erro registrado, segue | i = 4: 10 | i = 5: 5

-- 9. Exceção e transação.
CREATE TABLE tmp_registro (id NUMBER, origem VARCHAR2(30));

-- 9a. Exceção sem tratamento até o cliente: desfaz só o que a chamada fez.
INSERT INTO tmp_registro VALUES (1, 'antes do bloco');

DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    INSERT INTO tmp_registro VALUES (2, 'dentro do bloco');
    v_num := 1 / v_zero;
END;
/
-- Esperado: ORA-01476

-- Esperado: só a linha 1. A linha 2 foi desfeita; a 1, de antes da chamada, continua pendente.
SELECT id, origem FROM tmp_registro ORDER BY id;

ROLLBACK;

-- 9b. Exceção tratada: nada é desfeito automaticamente.
DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    INSERT INTO tmp_registro VALUES (2, 'dentro do bloco');
    v_num := 1 / v_zero;
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('Tratado');
END;
/

-- Esperado: a linha 2 está lá, pendente de COMMIT ou ROLLBACK.
SELECT id, origem FROM tmp_registro ORDER BY id;

ROLLBACK;

-- 9c. Subprograma que falha e o chamador trata: o que ele gravou fica.
--     O chamador decide com SAVEPOINT.
DECLARE
    PROCEDURE gravar_e_falhar IS
        v_zero PLS_INTEGER := 0;
        v_num  NUMBER;
    BEGIN
        INSERT INTO tmp_registro VALUES (3, 'subprograma');
        v_num := 1 / v_zero;
    END;
BEGIN
    INSERT INTO tmp_registro VALUES (4, 'chamador');

    SAVEPOINT antes_do_sub;
    BEGIN
        gravar_e_falhar;
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            DBMS_OUTPUT.PUT_LINE('Falhou; o INSERT do subprograma ainda está na transação');
            ROLLBACK TO SAVEPOINT antes_do_sub;
            DBMS_OUTPUT.PUT_LINE('Desfeito só o trecho do subprograma');
    END;
END;
/

-- Esperado: só a linha 4 (chamador). Sem o ROLLBACK TO SAVEPOINT, a 3 também estaria.
SELECT id, origem FROM tmp_registro ORDER BY id;

ROLLBACK;

DROP TABLE tmp_registro PURGE;
DROP TABLE tmp_clientes PURGE;
