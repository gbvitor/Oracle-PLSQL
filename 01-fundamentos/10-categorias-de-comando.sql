-- =============================================================================
-- Tópico : Categorias de comando — o commit implícito do DDL
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : usuário com CREATE TABLE
-- Usa só tabelas tmp_ criadas aqui e removidas no fim.
-- =============================================================================

CREATE TABLE tmp_registro (id NUMBER, descricao VARCHAR2(40));

-- 1. DML sem commit pode ser desfeito.
INSERT INTO tmp_registro VALUES (1, 'desfeito pelo rollback');
ROLLBACK;

-- Esperado: 0
SELECT COUNT(*) AS linhas FROM tmp_registro;

-- 2. Um DDL no meio confirma o DML anterior.
INSERT INTO tmp_registro VALUES (2, 'confirmado pelo CREATE TABLE');
CREATE TABLE tmp_outra (x NUMBER);
ROLLBACK;

-- Esperado: 1 (a linha 2 sobreviveu ao rollback)
SELECT COUNT(*) AS linhas FROM tmp_registro;

-- 3. O commit implícito vem antes da execução, então em geral acontece mesmo
--    quando o DDL falha. Se aqui der 1 em vez de 2, o erro foi detectado antes
--    do commit implícito (é o que ocorre com erro de sintaxe).
INSERT INTO tmp_registro VALUES (3, 'confirmado pelo DDL que falhou');
-- Esperado: ORA-00955 (nome já usado por objeto existente)
CREATE TABLE tmp_outra (x NUMBER);
ROLLBACK;

-- Esperado: 2 (a linha 3 também foi confirmada)
SELECT COUNT(*) AS linhas FROM tmp_registro;

-- 4. TRUNCATE é DDL: não tem rollback.
TRUNCATE TABLE tmp_registro;
ROLLBACK;

-- Esperado: 0
SELECT COUNT(*) AS linhas FROM tmp_registro;

-- 5. DELETE é DML: tem rollback.
INSERT INTO tmp_registro VALUES (4, 'volta depois do delete');
COMMIT;
DELETE FROM tmp_registro;
ROLLBACK;

-- Esperado: 1
SELECT COUNT(*) AS linhas FROM tmp_registro;

-- 6. Para saber se a sessão tem transação aberta.
--    Devolve um identificador quando há DML não confirmado; nulo quando não há.
UPDATE tmp_registro SET descricao = 'alterado' WHERE id = 4;

-- Esperado: um valor como 7.12.1234
SELECT DBMS_TRANSACTION.LOCAL_TRANSACTION_ID AS transacao_aberta FROM dual;

ROLLBACK;

-- Esperado: nulo
SELECT DBMS_TRANSACTION.LOCAL_TRANSACTION_ID AS transacao_aberta FROM dual;

-- Limpeza
DROP TABLE tmp_registro PURGE;
DROP TABLE tmp_outra PURGE;
