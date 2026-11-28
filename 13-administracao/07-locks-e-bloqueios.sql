-- =============================================================================
-- Tópico : Diagnóstico de bloqueio — cadeia de espera, bloqueadora inativa,
--          linha exata, ORA-00054 e DDL_LOCK_TIMEOUT
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : SELECT_CATALOG_ROLE (00-ambiente). Quatro sessões como o usuário de
--          estudo: A, B e C criam a cadeia; D (esta) diagnostica.
-- =============================================================================

SET LINESIZE 220
COLUMN arvore     FORMAT A40
COLUMN event      FORMAT A32 TRUNCATED
COLUMN object_name FORMAT A16

CREATE TABLE tmp_bloqueio AS SELECT id_cliente, nome, limite_credito FROM clientes;
ALTER TABLE tmp_bloqueio ADD CONSTRAINT pk_tmp_bloqueio PRIMARY KEY (id_cliente);

-- Montar a cadeia:
--   Sessão A: UPDATE tmp_bloqueio SET limite_credito = limite_credito + 1 WHERE id_cliente = 1;
--             (sem COMMIT; depois, não faça mais nada)
--   Sessão B: UPDATE tmp_bloqueio SET limite_credito = limite_credito + 1 WHERE id_cliente = 2;
--             UPDATE tmp_bloqueio SET limite_credito = limite_credito + 1 WHERE id_cliente = 1;
--             (fica esperando A, segurando a linha 2)
--   Sessão C: UPDATE tmp_bloqueio SET limite_credito = limite_credito + 1 WHERE id_cliente = 2;
--             (fica esperando B)

-- 1. Quem espera, por quem, e quem está no topo.
-- Esperado: B com blocking_session = A; C com blocking_session = B;
--           final_blocking_session = A para as duas; event enq: TX - row lock contention
SELECT sid, serial#, status, event, blocking_session, final_blocking_session, seconds_in_wait
  FROM v$session
 WHERE blocking_session IS NOT NULL
 ORDER BY sid;

-- 2. A árvore inteira, a partir de quem não espera ninguém.
-- Esperado:
--   A  INACTIVE  (o topo: transação aberta, nenhum SQL em execução)
--     B  ACTIVE  enq: TX - row lock contention
--       C  ACTIVE  enq: TX - row lock contention
WITH s AS (
    SELECT sid, serial#, username, status, event, blocking_session, last_call_et
      FROM v$session
     WHERE type = 'USER'
)
SELECT LPAD(' ', 2 * (LEVEL - 1)) || sid || ' (' || username || ')' AS arvore,
       status, event, last_call_et AS segundos
  FROM s
 START WITH blocking_session IS NULL
        AND sid IN (SELECT blocking_session FROM s)
CONNECT BY PRIOR sid = blocking_session
 ORDER SIBLINGS BY sid;

-- 3. O que a bloqueadora fez por último (o SQL do lock já terminou).
-- Esperado: sql_id vazio (inativa) e prev_sql_id apontando para o UPDATE da linha 1
COLUMN sql_text FORMAT A70 TRUNCATED
SELECT s.sid, s.status, s.sql_id, s.prev_sql_id, q.sql_text AS ultimo_sql
  FROM v$session s
  LEFT JOIN v$sql q ON q.sql_id = s.prev_sql_id AND q.child_number = s.prev_child_number
 WHERE s.sid IN (SELECT final_blocking_session FROM v$session WHERE final_blocking_session IS NOT NULL);

-- Transação aberta da bloqueadora: desde quando, quanto undo.
-- Esperado: start_time de quando A fez o UPDATE; used_urec (registros de undo) pequeno
SELECT s.sid, t.start_time, t.used_ublk, t.used_urec
  FROM v$transaction t
  JOIN v$session s ON s.taddr = t.addr
 ORDER BY t.start_time;

-- 4. Objeto e linha exata que a sessão B espera.
-- Esperado: TMP_BLOQUEIO e o ROWID da linha do cliente 1
SELECT s.sid,
       o.object_name,
       DBMS_ROWID.ROWID_CREATE(1, s.row_wait_obj#, s.row_wait_file#, s.row_wait_block#, s.row_wait_row#) AS linha
  FROM v$session s
  JOIN user_objects o ON o.object_id = s.row_wait_obj#
 WHERE s.blocking_session IS NOT NULL;

-- Com o ROWID, a linha (troque pelo valor exibido acima):
--   SELECT * FROM tmp_bloqueio WHERE ROWID = 'AAA...';
--   Esperado: cliente 1

-- 5. DDL com transação aberta na tabela.
-- Esperado: ORA-00054 na hora
ALTER TABLE tmp_bloqueio ADD observacao VARCHAR2(100);

-- Esperando até 5 segundos antes de desistir.
ALTER SESSION SET DDL_LOCK_TIMEOUT = 5;
-- Esperado: ORA-00054 depois de ~5 segundos (A ainda não terminou)
ALTER TABLE tmp_bloqueio ADD observacao VARCHAR2(100);
ALTER SESSION SET DDL_LOCK_TIMEOUT = 0;

-- 6. Resolver pelo topo:
--   Sessão A: ROLLBACK;   -> B recebe a linha 1 e termina; C continua esperando B
--   Sessão B: ROLLBACK;   -> C termina
--   Sessão C: ROLLBACK;

-- Esperado: nenhuma linha
SELECT sid FROM v$session WHERE blocking_session IS NOT NULL;

DROP TABLE tmp_bloqueio PURGE;
