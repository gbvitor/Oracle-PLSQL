-- =============================================================================
-- Tópico : Cursores implícitos — SQL%ROWCOUNT, SQL%FOUND, SQL%NOTFOUND
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_funcionarios AS SELECT * FROM funcionarios;
CREATE TABLE tmp_pedidos      AS SELECT * FROM pedidos;

-- 1. UPDATE que afeta linhas.
BEGIN
    UPDATE tmp_funcionarios
       SET salario = ROUND(salario * 1.05, 2)
     WHERE cargo = 'Vendedor';

    DBMS_OUTPUT.PUT_LINE('ROWCOUNT = ' || SQL%ROWCOUNT);
    DBMS_OUTPUT.PUT_LINE('FOUND    = ' || CASE WHEN SQL%FOUND THEN 'TRUE' ELSE 'FALSE' END);
    DBMS_OUTPUT.PUT_LINE('ISOPEN   = ' || CASE WHEN SQL%ISOPEN THEN 'TRUE' ELSE 'FALSE' END);
END;
/
-- Esperado: ROWCOUNT = 4 | FOUND = TRUE | ISOPEN = FALSE

-- Esperado: 19740 (era 18800)
SELECT SUM(salario) FROM tmp_funcionarios WHERE cargo = 'Vendedor';

ROLLBACK;

-- 2. UPDATE que não acha nada: não é erro.
BEGIN
    UPDATE tmp_funcionarios SET salario = salario + 100 WHERE id_departamento = 50;

    DBMS_OUTPUT.PUT_LINE('ROWCOUNT = ' || SQL%ROWCOUNT);
    DBMS_OUTPUT.PUT_LINE('NOTFOUND = ' || CASE WHEN SQL%NOTFOUND THEN 'TRUE' ELSE 'FALSE' END);
    DBMS_OUTPUT.PUT_LINE('Bloco terminou sem exceção');
END;
/
-- Esperado: ROWCOUNT = 0 | NOTFOUND = TRUE | Bloco terminou sem exceção
--           (o departamento 50, Marketing, não tem funcionários)

-- 3. Quando "nenhuma linha" é erro na regra, o código precisa dizer.
DECLARE
    v_id_funcionario tmp_funcionarios.id_funcionario%TYPE := 999;
BEGIN
    UPDATE tmp_funcionarios SET salario = salario + 100 WHERE id_funcionario = v_id_funcionario;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Funcionário ' || v_id_funcionario || ' não encontrado');
    END IF;
END;
/
-- Esperado: ORA-20010: Funcionário 999 não encontrado

-- 4. SELECT INTO: ROWCOUNT = 1 quando dá certo (inclusive com agregação).
DECLARE
    v_qtd PLS_INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_qtd FROM tmp_pedidos WHERE status = 'ABERTO';
    DBMS_OUTPUT.PUT_LINE('Pedidos abertos: ' || v_qtd || ' | SQL%ROWCOUNT = ' || SQL%ROWCOUNT);
END;
/
-- Esperado: Pedidos abertos: 3 | SQL%ROWCOUNT = 1
--           (o ROWCOUNT é o número de linhas que o SELECT devolveu, não o COUNT)

-- 5. O valor é sobrescrito pela instrução SQL seguinte.
DECLARE
    v_atualizados PLS_INTEGER;
    v_nome        tmp_funcionarios.nome%TYPE;
BEGIN
    UPDATE tmp_funcionarios SET salario = salario WHERE id_departamento = 20;
    v_atualizados := SQL%ROWCOUNT;

    SELECT nome INTO v_nome FROM tmp_funcionarios WHERE id_funcionario = 101;

    DBMS_OUTPUT.PUT_LINE('Guardado na variável: ' || v_atualizados);
    DBMS_OUTPUT.PUT_LINE('SQL%ROWCOUNT agora:   ' || SQL%ROWCOUNT);
END;
/
-- Esperado: Guardado na variável: 6 | SQL%ROWCOUNT agora: 1
--           (departamento 20: 101, 104, 105, 106, 107 e 108)

ROLLBACK;

-- 6. DELETE.
BEGIN
    DELETE FROM tmp_pedidos WHERE status = 'ABERTO';
    DBMS_OUTPUT.PUT_LINE('Excluídos: ' || SQL%ROWCOUNT);
END;
/
-- Esperado: Excluídos: 3 (1022, 1023 e 1024)

ROLLBACK;

-- 7. Padrão "atualiza; se não achou, insere".
CREATE TABLE tmp_estoque (
    id_produto NUMBER(6) CONSTRAINT pk_tmp_estoque PRIMARY KEY,
    qtd        NUMBER(10,3) NOT NULL
);

INSERT INTO tmp_estoque VALUES (1, 10);
COMMIT;

DECLARE
    PROCEDURE entrada(p_id NUMBER, p_qtd NUMBER) IS
    BEGIN
        UPDATE tmp_estoque SET qtd = qtd + p_qtd WHERE id_produto = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            INSERT INTO tmp_estoque (id_produto, qtd) VALUES (p_id, p_qtd);
            DBMS_OUTPUT.PUT_LINE('Produto ' || p_id || ': inserido');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Produto ' || p_id || ': atualizado');
        END IF;
    END;
BEGIN
    entrada(1, 5);
    entrada(2, 7);
END;
/
-- Esperado: Produto 1: atualizado | Produto 2: inserido

-- Esperado: 1 -> 15 | 2 -> 7
SELECT id_produto, qtd FROM tmp_estoque ORDER BY id_produto;

ROLLBACK;

DROP TABLE tmp_estoque      PURGE;
DROP TABLE tmp_pedidos      PURGE;
DROP TABLE tmp_funcionarios PURGE;
