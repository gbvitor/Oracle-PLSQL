-- =============================================================================
-- Tópico : Consistência de leitura
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente) e DUAS sessões como o usuário
--          de estudo. Execute cada bloco na sessão indicada, na ordem.
-- Cada alteração confirmada é desfeita em seguida; o schema volta ao estado original.
-- =============================================================================

-- ============================ SESSÃO A ======================================
-- A1. Alterar o preço do produto 1 sem confirmar.
UPDATE produtos SET preco_unitario = 99.99 WHERE id_produto = 1;

-- Esperado: 99.99 (a própria sessão vê a sua alteração pendente)
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- ============================ SESSÃO B ======================================
-- B1. A leitura não espera e não vê a alteração não confirmada.
-- Esperado: 39.90, na hora, sem bloqueio
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- B2. Mas alterar a mesma linha espera (bloqueio de linha, tópico 08).
--     Não execute aqui; o exemplo de bloqueio está no 08-locks.sql.

-- ============================ SESSÃO A ======================================
-- A2. Confirmar.
COMMIT;

-- ============================ SESSÃO B ======================================
-- B3. Em READ COMMITTED, o próximo comando já vê o valor confirmado.
-- Esperado: 99.99
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- ============================ SESSÃO A ======================================
-- A3. Voltar o preço original.
UPDATE produtos SET preco_unitario = 39.90 WHERE id_produto = 1;
COMMIT;

-- ============================ UMA SESSÃO ====================================
-- C1. Consistência dentro de um comando: um cursor aberto continua vendo a
--     fotografia do momento em que foi aberto, mesmo depois de a própria
--     sessão alterar e confirmar os dados.
SET SERVEROUTPUT ON

DECLARE
    CURSOR cur_produtos IS
        SELECT id_produto, preco_unitario FROM produtos WHERE id_produto IN (1, 2) ORDER BY id_produto;
    v_id    produtos.id_produto%TYPE;
    v_preco produtos.preco_unitario%TYPE;
BEGIN
    OPEN cur_produtos;

    -- Alteração feita e confirmada DEPOIS da abertura do cursor.
    UPDATE produtos SET preco_unitario = preco_unitario * 10 WHERE id_produto IN (1, 2);
    COMMIT;

    LOOP
        FETCH cur_produtos INTO v_id, v_preco;
        EXIT WHEN cur_produtos%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Cursor: produto ' || v_id || ' preco ' || v_preco);
    END LOOP;
    CLOSE cur_produtos;

    -- Esperado no cursor: 39.9 e 89.9 (valores do momento da abertura)

    SELECT preco_unitario INTO v_preco FROM produtos WHERE id_produto = 1;
    DBMS_OUTPUT.PUT_LINE('Consulta nova: produto 1 preco ' || v_preco);
    -- Esperado na consulta nova: 399

    -- Desfazer a alteração (já confirmada) com outro UPDATE.
    UPDATE produtos SET preco_unitario = preco_unitario / 10 WHERE id_produto IN (1, 2);
    COMMIT;
END;
/

-- Esperado: 39.90 e 89.90
SELECT id_produto, preco_unitario FROM produtos WHERE id_produto IN (1, 2) ORDER BY id_produto;
