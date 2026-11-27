-- =============================================================================
-- Tópico : Locks de linha, deadlock e FK sem índice
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), DUAS sessões como o usuário de
--          estudo, e acesso a V$SESSION / V$LOCKED_OBJECT.
-- Execute cada bloco na sessão indicada, na ordem. Tudo termina em ROLLBACK.
-- =============================================================================

-- ======================= PARTE 1: espera por linha ==========================

-- SESSÃO A ------------------------------------------------------------------
-- A1. Bloquear o produto 1.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 1;

-- SESSÃO B ------------------------------------------------------------------
-- B1. Outra linha da mesma tabela: não há espera (lock é por linha).
-- Esperado: 1 linha atualizada, na hora
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 2;

-- B2. A mesma linha: fica esperando. Deixe rodando e vá para a sessão A.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 1;

-- SESSÃO A ------------------------------------------------------------------
-- A2. Ver quem está esperando por quem.
-- Esperado: a sessão B com blocking_session = SID da sessão A,
--           event = 'enq: TX - row lock contention'
SELECT sid, serial#, username, blocking_session, event, seconds_in_wait
  FROM v$session
 WHERE username = USER;

-- A3. Liberar: a sessão B termina o UPDATE na hora.
ROLLBACK;

-- SESSÃO B ------------------------------------------------------------------
-- B3.
ROLLBACK;

-- ========================== PARTE 2: deadlock ===============================

-- SESSÃO A ------------------------------------------------------------------
-- A4. Bloquear o produto 1.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 1;

-- SESSÃO B ------------------------------------------------------------------
-- B4. Bloquear o produto 2.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 2;

-- SESSÃO A ------------------------------------------------------------------
-- A5. Pedir o produto 2 (está com B): A fica esperando.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 2;

-- SESSÃO B ------------------------------------------------------------------
-- B5. Pedir o produto 1 (está com A): ciclo fechado.
--     Em poucos segundos, uma das duas sessões recebe:
-- Esperado: ORA-00060 (detectado um impasse durante a espera de recurso)
--     A sessão que recebeu o erro teve só o último comando desfeito: o lock
--     anterior continua com ela, e a outra sessão continua esperando.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 1;

-- NAS DUAS SESSÕES ------------------------------------------------------------
-- A6 / B6. Encerrar: ROLLBACK primeiro na sessão que recebeu o ORA-00060.
ROLLBACK;

-- ===================== PARTE 3: FK sem índice ===============================

-- SESSÃO A ------------------------------------------------------------------
-- A7. Pai e filha, com a FK SEM índice.
CREATE TABLE tmp_pai   (id NUMBER PRIMARY KEY);
CREATE TABLE tmp_filha (id NUMBER PRIMARY KEY, id_pai NUMBER REFERENCES tmp_pai (id));
INSERT INTO tmp_pai SELECT LEVEL FROM dual CONNECT BY LEVEL <= 3;
INSERT INTO tmp_filha VALUES (1, 1);
COMMIT;

-- A8. Inserir um filho do pai 1, sem confirmar.
INSERT INTO tmp_filha VALUES (2, 1);

-- SESSÃO B ------------------------------------------------------------------
-- B7. Apagar o pai 3, que não tem filho nenhum.
--     Sem índice na FK, o Oracle precisa de lock na tabela filha inteira, e
--     espera a transação da sessão A terminar.
-- Esperado: fica esperando
DELETE FROM tmp_pai WHERE id = 3;

-- SESSÃO A ------------------------------------------------------------------
-- A9. Liberar.
ROLLBACK;

-- SESSÃO B ------------------------------------------------------------------
-- B8. O DELETE terminou. Desfazer.
ROLLBACK;

-- SESSÃO A ------------------------------------------------------------------
-- A10. Criar o índice na FK e repetir A8.
CREATE INDEX tmp_ix_filha_pai ON tmp_filha (id_pai);
INSERT INTO tmp_filha VALUES (2, 1);

-- SESSÃO B ------------------------------------------------------------------
-- B9. Agora o DELETE do pai 3 não espera.
-- Esperado: 1 linha apagada, na hora
DELETE FROM tmp_pai WHERE id = 3;
ROLLBACK;

-- SESSÃO A ------------------------------------------------------------------
-- A11. Limpeza.
ROLLBACK;
DROP TABLE tmp_filha PURGE;
DROP TABLE tmp_pai PURGE;
