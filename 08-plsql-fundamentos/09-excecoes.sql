-- =============================================================================
-- Tópico : Exceções predefinidas, do usuário e PRAGMA EXCEPTION_INIT
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE para o passo 7
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Predefinidas: cada caso num bloco aninhado, para o laço de testes continuar.
DECLARE
    v_num  NUMBER;
    v_txt  VARCHAR2(3);
    v_zero PLS_INTEGER := 0;
BEGIN
    BEGIN
        v_num := 10 / v_zero;
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            DBMS_OUTPUT.PUT_LINE('ZERO_DIVIDE      ' || SQLCODE);
    END;

    BEGIN
        v_num := TO_NUMBER('abc');
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('VALUE_ERROR      ' || SQLCODE || ' (conversão em PL/SQL)');
    END;

    BEGIN
        SELECT TO_NUMBER('abc') INTO v_num FROM dual;
    EXCEPTION
        WHEN INVALID_NUMBER THEN
            DBMS_OUTPUT.PUT_LINE('INVALID_NUMBER   ' || SQLCODE || ' (conversão em SQL)');
    END;

    BEGIN
        v_txt := 'abcdef';
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('VALUE_ERROR      ' || SQLCODE || ' (texto maior que a variável)');
    END;

    BEGIN
        SELECT id_cliente INTO v_num FROM clientes WHERE uf = 'SP';
    EXCEPTION
        WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('NDF ou TMR       ' || SQLCODE);
    END;
END;
/
-- Esperado:
--   ZERO_DIVIDE      -1476
--   VALUE_ERROR      -6502 (conversão em PL/SQL)
--   INVALID_NUMBER   -1722 (conversão em SQL)
--   VALUE_ERROR      -6502 (texto maior que a variável)
--   NDF ou TMR       -1422

-- 2. DUP_VAL_ON_INDEX.
CREATE TABLE tmp_clientes AS SELECT * FROM clientes;
ALTER TABLE tmp_clientes ADD CONSTRAINT pk_tmp_clientes PRIMARY KEY (id_cliente);

BEGIN
    INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, cidade, uf)
    VALUES (1, 'Duplicado', 'F', '99999999999', 'Palmas', 'TO');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Cliente 1 já existe: ' || SQLERRM);
END;
/
-- Esperado: Cliente 1 já existe: ORA-00001: restrição exclusiva (ESTUDO.PK_TMP_CLIENTES) violada
--           (o texto exato da mensagem depende do idioma da sessão e da versão)

-- 3. Exceção do usuário: limite de crédito.
--    Em aberto = pedidos ABERTO ou FATURADO. Cliente 9: limite 4000, em aberto 899 (pedido 1023).
DECLARE
    e_limite_excedido EXCEPTION;

    PROCEDURE validar(p_cliente NUMBER, p_valor_novo NUMBER) IS
        v_limite    clientes.limite_credito%TYPE;
        v_em_aberto NUMBER;
    BEGIN
        SELECT limite_credito INTO v_limite FROM clientes WHERE id_cliente = p_cliente;

        SELECT NVL(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)), 0)
          INTO v_em_aberto
          FROM pedidos p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.id_cliente = p_cliente
           AND p.status IN ('ABERTO', 'FATURADO');

        IF v_em_aberto + p_valor_novo > v_limite THEN
            RAISE e_limite_excedido;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Novo pedido de ' || p_valor_novo || ': ok (' || (v_em_aberto + p_valor_novo) || ' de ' || v_limite || ')');
    END;
BEGIN
    validar(9, 3000);
    validar(9, 3500);
    DBMS_OUTPUT.PUT_LINE('não chega aqui');
EXCEPTION
    WHEN e_limite_excedido THEN
        DBMS_OUTPUT.PUT_LINE('Limite excedido | SQLCODE ' || SQLCODE || ' | ' || SQLERRM);
END;
/
-- Esperado:
--   Novo pedido de 3000: ok (3899 de 4000)
--   Limite excedido | SQLCODE 1 | User-Defined Exception

-- 4. PRAGMA EXCEPTION_INIT: dar nome a erros de constraint.
DECLARE
    e_registro_filho EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_registro_filho, -2292);

    e_pai_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_pai_inexistente, -2291);

    e_obrigatorio EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_obrigatorio, -1400);
BEGIN
    BEGIN
        DELETE FROM clientes WHERE id_cliente = 1;
    EXCEPTION
        WHEN e_registro_filho THEN
            DBMS_OUTPUT.PUT_LINE('-2292: cliente 1 tem pedidos, não pode ser excluído');
    END;

    BEGIN
        INSERT INTO pedidos (id_pedido, id_cliente, data_pedido) VALUES (9001, 999, SYSDATE);
    EXCEPTION
        WHEN e_pai_inexistente THEN
            DBMS_OUTPUT.PUT_LINE('-2291: cliente 999 não existe');
    END;

    BEGIN
        INSERT INTO pedidos (id_pedido, id_cliente, data_pedido) VALUES (9001, 1, NULL);
    EXCEPTION
        WHEN e_obrigatorio THEN
            DBMS_OUTPUT.PUT_LINE('-1400: data_pedido é obrigatória');
    END;
END;
/
-- Esperado:
--   -2292: cliente 1 tem pedidos, não pode ser excluído
--   -2291: cliente 999 não existe
--   -1400: data_pedido é obrigatória
--   (nenhuma das três instruções alterou dados)

-- 5. A mesma exceção pega por nome ou por OTHERS + SQLCODE: o nome é mais legível.
BEGIN
    DELETE FROM clientes WHERE id_cliente = 1;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -2292 THEN
            DBMS_OUTPUT.PUT_LINE('Mesmo erro, testado por código');
        ELSE
            RAISE;
        END IF;
END;
/
-- Esperado: Mesmo erro, testado por código

-- 6. WHEN OTHERS THEN NULL esconde o erro.
DECLARE
    v_nome clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE uf = 'SP';
    DBMS_OUTPUT.PUT_LINE('Nome: ' || v_nome);
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/
-- Esperado: "Procedimento PL/SQL concluído com sucesso", sem nada impresso.
--           O TOO_MANY_ROWS aconteceu e ninguém ficou sabendo.

-- 7. Aviso do compilador para OTHERS que não termina em RAISE.
ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL';

CREATE OR REPLACE PROCEDURE tmp_proc_engole IS
    v_nome clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE uf = 'SP';
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

-- Esperado: entre os avisos, PLW-06009 (o tratador OTHERS não termina em RAISE
--           ou RAISE_APPLICATION_ERROR)
SHOW ERRORS PROCEDURE tmp_proc_engole

ALTER SESSION SET PLSQL_WARNINGS = 'DISABLE:ALL';

DROP PROCEDURE tmp_proc_engole;
DROP TABLE tmp_clientes PURGE;
