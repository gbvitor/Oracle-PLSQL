-- =============================================================================
-- Tópico : Procedures — parâmetros IN, OUT, IN OUT, DEFAULT, notação, erros
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

-- 1. Procedure com IN, DEFAULT e OUT.
CREATE OR REPLACE PROCEDURE tmp_reajustar_categoria (
    p_id_categoria IN  tmp_produtos.id_categoria%TYPE,
    p_pct          IN  NUMBER DEFAULT 5,
    p_qtd          OUT PLS_INTEGER
) IS
    v_fator NUMBER;
BEGIN
    v_fator := 1 + p_pct / 100;

    UPDATE tmp_produtos
       SET preco_unitario = ROUND(preco_unitario * v_fator, 2)
     WHERE id_categoria = p_id_categoria;

    p_qtd := SQL%ROWCOUNT;
END tmp_reajustar_categoria;
/

-- 2. Três notações de chamada.
DECLARE
    v_qtd PLS_INTEGER;
BEGIN
    tmp_reajustar_categoria(p_id_categoria => 5, p_qtd => v_qtd);
    DBMS_OUTPUT.PUT_LINE('Nomeada, pct padrão (5%): ' || v_qtd || ' produtos');
END;
/
-- Esperado: Nomeada, pct padrão (5%): 3 produtos

-- Esperado: 8 -> 34.13 | 9 -> 47.25 | 10 -> 29.19
SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 5 ORDER BY id_produto;

ROLLBACK;

DECLARE
    v_qtd PLS_INTEGER;
BEGIN
    tmp_reajustar_categoria(5, 10, v_qtd);
    DBMS_OUTPUT.PUT_LINE('Posicional, 10%: ' || v_qtd);
    ROLLBACK;

    tmp_reajustar_categoria(7, p_qtd => v_qtd);
    DBMS_OUTPUT.PUT_LINE('Mista, categoria 7: ' || v_qtd);
    ROLLBACK;
END;
/
-- Esperado: Posicional, 10%: 3 | Mista, categoria 7: 2

-- 3. Chamada pelo SQL*Plus com variável de ligação.
VARIABLE qtd NUMBER
EXEC tmp_reajustar_categoria(2, 0, :qtd)
PRINT qtd
-- Esperado: 5 (categoria 2 tem cinco produtos; 0% não muda preço)

ROLLBACK;

-- 4. OUT começa NULL, mesmo que a variável do chamador tenha valor.
--    IN OUT recebe o valor do chamador.
CREATE OR REPLACE PROCEDURE tmp_modos (
    p_out    OUT    NUMBER,
    p_in_out IN OUT NUMBER
) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Na entrada: p_out = [' || p_out || '] | p_in_out = [' || p_in_out || ']');
    p_out    := 1;
    p_in_out := p_in_out * 2;
END tmp_modos;
/

DECLARE
    v_a NUMBER := 100;
    v_b NUMBER := 100;
BEGIN
    tmp_modos(v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('Depois:     v_a = ' || v_a || ' | v_b = ' || v_b);
END;
/
-- Esperado:
--   Na entrada: p_out = [] | p_in_out = [100]
--   Depois:     v_a = 1 | v_b = 200

-- 5. Exceção não tratada: o OUT do chamador não muda.
CREATE OR REPLACE PROCEDURE tmp_falha_depois (p_out OUT NUMBER) IS
BEGIN
    p_out := 99;
    RAISE_APPLICATION_ERROR(-20001, 'falhou depois de atribuir');
END tmp_falha_depois;
/

DECLARE
    v NUMBER := 10;
BEGIN
    tmp_falha_depois(v);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Depois da falha: v = ' || v);
END;
/
-- Esperado: Depois da falha: v = 10 (a cópia de volta do 99 não aconteceu)

-- 6. Atribuir a parâmetro IN: erro de compilação, objeto fica INVALID.
CREATE OR REPLACE PROCEDURE tmp_altera_in (p_valor IN NUMBER) IS
BEGIN
    p_valor := p_valor + 1;
END tmp_altera_in;
/
-- Esperado: "Advertência: Procedimento criado com erros de compilação."

SHOW ERRORS PROCEDURE tmp_altera_in
-- Esperado: PLS-00363 (a expressão 'P_VALOR' não pode ser usada como destino de atribuição)

-- Esperado: TMP_ALTERA_IN | INVALID
SELECT object_name, status FROM user_objects WHERE object_name = 'TMP_ALTERA_IN';

-- Esperado: linha, coluna e texto do erro
SELECT line, position, text FROM user_errors WHERE name = 'TMP_ALTERA_IN' ORDER BY sequence;

-- 7. Parâmetro com tamanho: erro de sintaxe.
CREATE OR REPLACE PROCEDURE tmp_tamanho (p_uf IN CHAR(2)) IS
BEGIN
    NULL;
END tmp_tamanho;
/
-- Esperado: criado com erros; SHOW ERRORS mostra PLS-00103 (símbolo "(" encontrado)

SHOW ERRORS PROCEDURE tmp_tamanho

-- 8. Chamar procedure inválida.
BEGIN
    tmp_altera_in(1);
END;
/
-- Esperado: PLS-00905 (o objeto ESTUDO.TMP_ALTERA_IN é inválido)

-- 9. Código-fonte guardado no dicionário (DBMS_METADATA é o caminho para o DDL completo).
SET LONG 10000
SELECT DBMS_METADATA.GET_DDL('PROCEDURE', 'TMP_MODOS') AS ddl FROM dual;

DROP PROCEDURE tmp_tamanho;
DROP PROCEDURE tmp_altera_in;
DROP PROCEDURE tmp_falha_depois;
DROP PROCEDURE tmp_modos;
DROP PROCEDURE tmp_reajustar_categoria;
DROP TABLE tmp_produtos PURGE;
