-- =============================================================================
-- Tópico : Arquitetura — memória, processos e arquivos vistos pelas V$ e DBA_
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : SELECT_CATALOG_ROLE ou SELECT ANY DICTIONARY (00-ambiente).
--          Só consultas: nada é alterado.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 100
COLUMN name   FORMAT A40
COLUMN member FORMAT A60

-- 1. Instância e banco.
-- Esperado: nome da instância (FREE no container), versão, status OPEN, data de início
SELECT instance_name, host_name, version_full, status, startup_time FROM v$instance;

-- Esperado: nome do banco, modo de log (NOARCHIVELOG no container de estudo), CDB YES
SELECT name, log_mode, open_mode, cdb, created FROM v$database;

-- 2. Memória: SGA por componente e PGA.
-- Esperado: Buffer Cache, Shared Pool, Redo Buffers, Large Pool... com o tamanho em MB
SELECT name, ROUND(bytes / 1024 / 1024) AS mb, resizeable
  FROM v$sgainfo
 ORDER BY bytes DESC;

-- Esperado: total PGA allocated, maximum PGA allocated, aggregate PGA target parameter
SELECT name, ROUND(value / 1024 / 1024) AS mb
  FROM v$pgastat
 WHERE name IN ('aggregate PGA target parameter', 'total PGA allocated', 'maximum PGA allocated');

-- PGA da minha sessão.
-- Esperado: alguns MB; cresce com ordenações grandes e coleções PL/SQL
SELECT ROUND(p.pga_used_mem / 1024 / 1024, 1) AS pga_usada_mb,
       ROUND(p.pga_max_mem  / 1024 / 1024, 1) AS pga_maxima_mb
  FROM v$process p
  JOIN v$session s ON s.paddr = p.addr
 WHERE s.sid = SYS_CONTEXT('USERENV', 'SID');

-- 3. Parâmetros de memória.
SELECT name, display_value
  FROM v$parameter
 WHERE name IN ('sga_target', 'sga_max_size', 'pga_aggregate_target', 'pga_aggregate_limit', 'memory_target')
 ORDER BY name;

-- 4. Processos de segundo plano em execução.
-- Esperado: PMON, SMON, DBW0, LGWR, CKPT, MMON... (a lista completa tem dezenas)
SELECT name, description
  FROM v$bgprocess
 WHERE paddr <> '00'
 ORDER BY name;

-- 5. Arquivos.
-- Esperado: arquivos de dados do PDB atual (SYSTEM, SYSAUX, UNDOTBS1, USERS)
SELECT tablespace_name, file_name, ROUND(bytes / 1024 / 1024) AS mb, autoextensible
  FROM dba_data_files
 ORDER BY tablespace_name;

-- Esperado: o arquivo do tablespace TEMP
SELECT tablespace_name, file_name, ROUND(bytes / 1024 / 1024) AS mb FROM dba_temp_files;

-- Control files.
-- Esperado: um ou mais control files (multiplexados em produção)
SELECT name FROM v$controlfile;

-- Redo logs: grupos, tamanho e qual está em uso.
-- Esperado: 3 grupos (normalmente), um CURRENT, os outros INACTIVE ou ACTIVE
SELECT l.group#, l.sequence#, ROUND(l.bytes / 1024 / 1024) AS mb, l.status, f.member
  FROM v$log l
  JOIN v$logfile f ON f.group# = l.group#
 ORDER BY l.group#;

-- 6. Onde ficam o alert log e os traces.
COLUMN value FORMAT A80
SELECT name, value FROM v$diag_info WHERE name IN ('Diag Trace', 'Diag Alert', 'Default Trace File');

-- Últimas mensagens do alert log, sem acessar o servidor (exige leitura de V$DIAG_ALERT_EXT).
COLUMN message_text FORMAT A100 TRUNCATED
SELECT originating_timestamp, message_text
  FROM v$diag_alert_ext
 WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
 ORDER BY originating_timestamp DESC
 FETCH FIRST 20 ROWS ONLY;

-- 7. Undo: tamanho e retenção.
-- Esperado: undo_management AUTO, undo_retention 900 (segundos, padrão), undo_tablespace UNDOTBS1
SELECT name, value FROM v$parameter WHERE name LIKE 'undo%' ORDER BY name;

-- 8. Redo gerado pela minha sessão: medir o custo de um DML.
COLUMN redo FORMAT 999G999G999
CREATE TABLE tmp_redo AS SELECT * FROM clientes WHERE 1 = 0;

SELECT m.value AS redo FROM v$mystat m JOIN v$statname n ON n.statistic# = m.statistic# WHERE n.name = 'redo size';

INSERT INTO tmp_redo SELECT * FROM clientes;
COMMIT;

-- Esperado: o valor aumentou alguns KB (12 linhas numa tabela sem índice)
SELECT m.value AS redo FROM v$mystat m JOIN v$statname n ON n.statistic# = m.statistic# WHERE n.name = 'redo size';

DROP TABLE tmp_redo PURGE;
