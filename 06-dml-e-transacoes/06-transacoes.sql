-- =============================================================================
-- Tópico : COMMIT, ROLLBACK, SAVEPOINT e atomicidade por comando
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

SET SERVEROUTPUT ON

CREATE TABLE tmp_log (passo NUMBER, descricao VARCHAR2(60));

-- 1. SAVEPOINT: desfazer só uma parte.
INSERT INTO tmp_log VALUES (1, 'cabecalho do pedido');
SAVEPOINT antes_itens;

INSERT INTO tmp_log VALUES (2, 'item 1');
INSERT INTO tmp_log VALUES (3, 'item 2');

ROLLBACK TO antes_itens;

-- Esperado: só o passo 1 (a transação continua aberta)
SELECT * FROM tmp_log ORDER BY passo;

COMMIT;

-- 2. Vários savepoints: voltar a um anterior descarta os posteriores.
INSERT INTO tmp_log VALUES (10, 'a');
SAVEPOINT sp_a;
INSERT INTO tmp_log VALUES (11, 'b');
SAVEPOINT sp_b;
INSERT INTO tmp_log VALUES (12, 'c');

ROLLBACK TO sp_a;

-- sp_b deixou de existir.
-- Esperado: ORA-01086 (savepoint 'SP_B' nunca estabelecido nesta sessão ou é inválido)
ROLLBACK TO sp_b;

-- Esperado: passos 1 e 10
SELECT * FROM tmp_log ORDER BY passo;

ROLLBACK;

-- 3. Atomicidade por comando: o comando que falha é desfeito sozinho.
INSERT INTO tmp_log VALUES (20, 'antes do erro');

-- Esperado: ORA-12899 (valor muito grande para a coluna)
INSERT INTO tmp_log VALUES (21, RPAD('x', 100, 'x'));

INSERT INTO tmp_log VALUES (22, 'depois do erro');

-- Esperado: passos 1, 20 e 22 (o 21 foi desfeito; 20 e 22 continuam pendentes)
SELECT * FROM tmp_log ORDER BY passo;

ROLLBACK;

-- Esperado: só o passo 1
SELECT * FROM tmp_log ORDER BY passo;

-- 4. Comando de várias linhas que falha no meio: desfaz o comando inteiro.
--    A terceira linha da origem estoura o tamanho da coluna.
-- Esperado: ORA-12899; nenhuma das 3 linhas fica
INSERT INTO tmp_log (passo, descricao)
SELECT LEVEL + 30, CASE WHEN LEVEL = 3 THEN RPAD('x', 100, 'x') ELSE 'linha ' || LEVEL END
  FROM dual CONNECT BY LEVEL <= 3;

-- Esperado: 1 (só o passo 1)
SELECT COUNT(*) FROM tmp_log;

-- 5. Em PL/SQL: exceção não tratada desfaz o bloco inteiro;
--    exceção tratada deixa a decisão com o código.
BEGIN
    INSERT INTO tmp_log VALUES (40, 'dentro do bloco');
    INSERT INTO tmp_log VALUES (41, RPAD('x', 100, 'x'));
END;
/
-- Esperado: ORA-12899; o passo 40 também foi desfeito (a chamada é um comando só)

-- Esperado: 1
SELECT COUNT(*) FROM tmp_log;

BEGIN
    INSERT INTO tmp_log VALUES (50, 'antes do erro tratado');
    BEGIN
        INSERT INTO tmp_log VALUES (51, RPAD('x', 100, 'x'));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Erro tratado: ' || SQLERRM);
    END;
    INSERT INTO tmp_log VALUES (52, 'depois do erro tratado');
END;
/

-- Esperado: passos 1, 50 e 52 (pendentes)
SELECT * FROM tmp_log ORDER BY passo;

ROLLBACK;

-- 6. Há transação aberta?
INSERT INTO tmp_log VALUES (60, 'pendente');

-- Esperado: um identificador (transação aberta)
SELECT DBMS_TRANSACTION.LOCAL_TRANSACTION_ID AS transacao FROM dual;

COMMIT;

-- Esperado: nulo
SELECT DBMS_TRANSACTION.LOCAL_TRANSACTION_ID AS transacao FROM dual;

-- Limpeza
DROP TABLE tmp_log PURGE;
