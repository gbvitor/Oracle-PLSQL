-- =============================================================================
-- Tópico : Sessões — quem está conectado, o que está fazendo, operações longas,
--          cancelar e encerrar
-- Seção  : 13-administracao
-- Versão : 19c (CANCEL SQL exige 18c+)
-- Requer : SELECT_CATALOG_ROLE (00-ambiente) para as consultas; ALTER SYSTEM [DBA]
--          para encerrar. O passo 4 usa duas sessões.
-- =============================================================================

SET LINESIZE 220
SET PAGESIZE 100
COLUMN username   FORMAT A12
COLUMN osuser     FORMAT A12
COLUMN machine    FORMAT A20 TRUNCATED
COLUMN program    FORMAT A24 TRUNCATED
COLUMN module     FORMAT A24 TRUNCATED
COLUMN event      FORMAT A30 TRUNCATED
COLUMN sql_text   FORMAT A50 TRUNCATED
COLUMN opname     FORMAT A24 TRUNCATED

-- 1. Sessões de usuário, com o processo do sistema operacional.
-- Esperado: ao menos a sua sessão (ESTUDO, ACTIVE)
SELECT s.sid, s.serial#, p.spid, s.username, s.osuser, s.machine, s.program, s.status,
       s.logon_time
  FROM v$session s
  JOIN v$process p ON p.addr = s.paddr
 WHERE s.type = 'USER'
 ORDER BY s.logon_time;

-- 2. O que as sessões ativas estão executando, há quanto tempo.
-- Esperado: a sua sessão, executando esta consulta, com last_call_et 0
SELECT s.sid, s.serial#, s.username, s.last_call_et AS segundos, s.event, s.sql_id, q.sql_text
  FROM v$session s
  LEFT JOIN v$sql q ON q.sql_id = s.sql_id AND q.child_number = s.sql_child_number
 WHERE s.type = 'USER'
   AND s.status = 'ACTIVE'
 ORDER BY s.last_call_et DESC;

-- 3. Identificar a sessão do jeito que uma aplicação deveria fazer.
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('usuario.app@exemplo');
    DBMS_APPLICATION_INFO.SET_MODULE('tmp_faturamento', 'gerando notas');
END;
/

-- Esperado: usuario.app@exemplo | tmp_faturamento | gerando notas
SELECT sid, client_identifier, module, action FROM v$session WHERE sid = SYS_CONTEXT('USERENV', 'SID');

BEGIN
    DBMS_SESSION.CLEAR_IDENTIFIER;
    DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL);
END;
/

-- 4. Operação longa, acompanhada de outra sessão.
--    Sessão A: uma leitura completa demorada (produto cartesiano, de propósito).
--      SELECT /* tmp_longa */ COUNT(*) FROM all_objects a, all_objects b WHERE ROWNUM <= 1e9;
--
--    Sessão B (esta), enquanto A roda:

-- Esperado: a operação da sessão A, com sofar crescendo e time_remaining estimado
--           (só operações de mais de alguns segundos entram, e nem toda operação é
--           registrada: se não aparecer nada, a consulta seguinte acha a sessão mesmo assim)
SELECT sid, opname, target, sofar, totalwork,
       ROUND(100 * sofar / NULLIF(totalwork, 0)) AS pct,
       time_remaining
  FROM v$session_longops
 WHERE sofar < totalwork
 ORDER BY start_time DESC;

-- Achar a sessão A pelo texto em execução.
-- Esperado: SID e SERIAL# da sessão A
SELECT s.sid, s.serial#, s.username, s.last_call_et
  FROM v$session s
  JOIN v$sql q ON q.sql_id = s.sql_id
 WHERE q.sql_text LIKE 'SELECT /* tmp_longa */%'
   AND s.status = 'ACTIVE';

-- 5. [DBA] Cancelar só a instrução [18c+], sem derrubar a sessão:
--      ALTER SYSTEM CANCEL SQL '<sid>,<serial#>';
--    Esperado na sessão A: ORA-01013 (o usuário solicitou cancelamento da operação atual);
--                          a sessão continua conectada.
--
--    [DBA] Encerrar a sessão:
--      ALTER SYSTEM KILL SESSION '<sid>,<serial#>' IMMEDIATE;
--    Esperado na sessão A, no próximo comando: ORA-00028 (sua sessão foi encerrada)
--                          ou ORA-03113/ORA-03135 (conexão perdida)
--
--    Pela própria sessão A, Ctrl+C também cancela a instrução: ORA-01013.

-- 6. Sessões por usuário e por programa (visão de capacidade).
SELECT username, program, status, COUNT(*) AS sessoes
  FROM v$session
 WHERE type = 'USER'
 GROUP BY username, program, status
 ORDER BY sessoes DESC;

-- Limite configurado.
-- Esperado: processes e sessions (o número de sessões cresce com processes)
SELECT name, value FROM v$parameter WHERE name IN ('processes', 'sessions');
