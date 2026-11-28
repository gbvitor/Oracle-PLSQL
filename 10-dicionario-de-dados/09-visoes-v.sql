-- =============================================================================
-- Tópico : Visões dinâmicas V$ — V$SESSION, V$SQL, V$LOCK, V$MYSTAT,
--          V$PARAMETER, bloqueio entre sessões
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : SELECT_CATALOG_ROLE ou SELECT ANY DICTIONARY (00-ambiente).
--          Passo 6 usa três sessões como o mesmo usuário.
-- =============================================================================

COLUMN username   FORMAT A12
COLUMN program    FORMAT A26
COLUMN module     FORMAT A26
COLUMN event      FORMAT A34
COLUMN sql_text   FORMAT A60 TRUNCATED
COLUMN banner     FORMAT A80
COLUMN name       FORMAT A32
COLUMN value      FORMAT A30

-- 1. Versão e instância.
-- Esperado: Oracle Database 19c ... (ou 23ai/26ai Free) e o nome da instância
SELECT banner_full AS banner FROM v$version;
SELECT instance_name, host_name, version_full, status, startup_time FROM v$instance;

-- 2. A minha sessão.
-- Esperado: uma linha com o seu SID, ESTUDO, ACTIVE e o programa cliente (sqlplus, SQL Developer...)
SELECT sid, serial#, username, status, program, module, logon_time
  FROM v$session
 WHERE sid = SYS_CONTEXT('USERENV', 'SID');

-- 3. Quem está conectado: sessões de usuário por estado.
SELECT username, status, COUNT(*) AS sessoes
  FROM v$session
 WHERE type = 'USER'
 GROUP BY username, status
 ORDER BY username, status;

-- O que as sessões ativas estão esperando.
SELECT sid, username, event, wait_class, last_call_et AS segundos, sql_id
  FROM v$session
 WHERE type = 'USER'
   AND status = 'ACTIVE'
 ORDER BY last_call_et DESC;

-- 4. Achar um SQL em memória pelo texto e ver o custo dele.
SELECT /* tmp_marcador_v_sql */ COUNT(*) FROM itens_pedido i JOIN pedidos p ON p.id_pedido = i.id_pedido;
SELECT /* tmp_marcador_v_sql */ COUNT(*) FROM itens_pedido i JOIN pedidos p ON p.id_pedido = i.id_pedido;

-- Esperado: uma linha, executions 2, rows_processed 2, buffer_gets pequeno
--           (o filtro NOT LIKE tira a própria consulta de busca)
SELECT sql_id, child_number, executions, rows_processed, buffer_gets,
       ROUND(elapsed_time / 1000, 1) AS ms_total, sql_text
  FROM v$sql
 WHERE sql_text LIKE '%tmp_marcador_v_sql%'
   AND sql_text NOT LIKE '%v$sql%';

-- 5. Os SQLs mais caros deste schema, em leituras lógicas por execução.
SELECT *
  FROM (SELECT sql_id,
               executions,
               ROUND(buffer_gets / NULLIF(executions, 0))           AS leituras_por_exec,
               ROUND(elapsed_time / NULLIF(executions, 0) / 1000, 2) AS ms_por_exec,
               sql_text
          FROM v$sql
         WHERE parsing_schema_name = USER
         ORDER BY buffer_gets DESC)
 WHERE ROWNUM <= 5;

-- 6. Bloqueio entre sessões (três janelas, mesmo usuário).
CREATE TABLE tmp_trava AS SELECT id_cliente, nome, limite_credito FROM clientes;

-- Sessão A:
--   UPDATE tmp_trava SET limite_credito = limite_credito + 1 WHERE id_cliente = 1;
--   (não faça COMMIT)
--
-- Sessão B:
--   UPDATE tmp_trava SET limite_credito = limite_credito + 2 WHERE id_cliente = 1;
--   (fica parada, esperando)
--
-- Sessão C (ou esta), enquanto B espera:

-- Esperado: a sessão B, com blocking_session = SID da sessão A e
--           event = enq: TX - row lock contention
SELECT sid, serial#, username, event, blocking_session, seconds_in_wait, sql_id
  FROM v$session
 WHERE blocking_session IS NOT NULL;

-- Esperado: duas linhas TX para A e B (A com LMODE 6 e BLOCK 1; B com REQUEST 6),
--           e linhas TM das duas na tabela
SELECT l.sid, l.type, l.lmode, l.request, l.block, o.object_name
  FROM v$lock l
  LEFT JOIN user_objects o ON o.object_id = l.id1 AND l.type = 'TM'
 WHERE l.type IN ('TX', 'TM')
   AND l.sid IN (SELECT sid FROM v$session WHERE username = USER)
 ORDER BY l.sid, l.type;

-- Que objeto está travado por quem.
-- Esperado: TMP_TRAVA com as duas sessões
SELECT lo.session_id AS sid, o.object_name, lo.locked_mode, s.status
  FROM v$locked_object lo
  JOIN user_objects o ON o.object_id = lo.object_id
  JOIN v$session s    ON s.sid = lo.session_id;

-- Sessão A: ROLLBACK;   -> a sessão B é liberada na hora
-- Sessão B: ROLLBACK;

-- 7. Estatísticas da própria sessão: leituras lógicas de uma consulta.
COLUMN leituras FORMAT 999999999
SELECT n.name, m.value AS leituras
  FROM v$mystat m
  JOIN v$statname n ON n.statistic# = m.statistic#
 WHERE n.name = 'session logical reads';

SELECT COUNT(*) FROM itens_pedido i JOIN produtos p ON p.id_produto = i.id_produto;

-- Esperado: o valor aumentou; a diferença é o trabalho da consulta acima
--           (mais o da própria consulta à V$MYSTAT)
SELECT n.name, m.value AS leituras
  FROM v$mystat m
  JOIN v$statname n ON n.statistic# = m.statistic#
 WHERE n.name = 'session logical reads';

-- 8. Parâmetros em vigor.
SELECT name, value, isdefault
  FROM v$parameter
 WHERE name IN ('db_block_size', 'open_cursors', 'processes', 'optimizer_mode',
                'nls_language', 'nls_territory', 'control_management_pack_access')
 ORDER BY name;
-- Esperado: db_block_size 8192, optimizer_mode ALL_ROWS;
--           control_management_pack_access indica se Diagnostics/Tuning Pack estão habilitados

DROP TABLE tmp_trava PURGE;
