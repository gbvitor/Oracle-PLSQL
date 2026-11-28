-- =============================================================================
-- Tópico : Ferramentas — AUTOTRACE, SQL trace, verificação de licença antes de
--          usar AWR/ASH/SQL Monitor
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql; leitura de V$ (SELECT_CATALOG_ROLE). O passo 3 gera
--          arquivo de trace no servidor; ler o arquivo exige acesso ao servidor.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 200

-- 1. Antes de tudo: o que está habilitado e o que já foi usado neste banco.
-- Esperado: control_management_pack_access = DIAGNOSTIC+TUNING, DIAGNOSTIC ou NONE.
--           Habilitado não quer dizer licenciado: confirme com quem cuida dos contratos.
SELECT name, value FROM v$parameter WHERE name = 'control_management_pack_access';

-- Registro de uso de recursos (o que uma auditoria de licenças consulta).
COLUMN name FORMAT A50
-- Esperado: linhas como "Automatic Workload Repository", "Real-Time SQL Monitoring",
--           com detected_usages > 0 se já foram usados
SELECT name, detected_usages, currently_used, last_usage_date
  FROM dba_feature_usage_statistics
 WHERE name IN ('Automatic Workload Repository', 'Active Session History',
                'Real-Time SQL Monitoring', 'SQL Tuning Advisor', 'ADDM')
 ORDER BY name;

-- Edição do banco: Standard Edition 2 não licencia os packs.
-- Esperado: "Enterprise Edition", "Standard Edition 2" ou "Free" no banner
SELECT banner_full FROM v$version;

-- 2. AUTOTRACE: plano e estatísticas de execução, sem licença adicional.
SET AUTOTRACE TRACEONLY

SELECT * FROM tmp_perf_pedidos WHERE id_cliente = 42;

-- Esperado: plano com INDEX RANGE SCAN e estatísticas como
--   consistent gets   ~100 a 120 (um bloco por pedido, mais o índice)
--   physical reads    0 se os blocos já estavam em cache
--   rows processed    100

SELECT * FROM tmp_perf_pedidos WHERE status = 'CANCELADO';

-- Esperado: TABLE ACCESS FULL e consistent gets na casa de milhares (todos os blocos)
--           para devolver 200 linhas: o custo do erro de estimativa (tópico 05)

SET AUTOTRACE TRACEONLY STATISTICS

SELECT c.uf, SUM(p.valor)
  FROM tmp_perf_clientes c
  JOIN tmp_perf_pedidos p ON p.id_cliente = c.id_cliente
 GROUP BY c.uf;

-- Esperado: sorts (memory) 0 ou 1, sorts (disk) 0, rows processed 10

SET AUTOTRACE OFF

-- 3. SQL trace da própria sessão.
-- Onde o arquivo vai ser gravado.
COLUMN value FORMAT A100
SELECT value FROM v$diag_info WHERE name = 'Default Trace File';

-- Identificar o arquivo e ligar o trace com esperas.
ALTER SESSION SET tracefile_identifier = 'tmp_estudo';
EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(waits => TRUE, binds => FALSE)

SELECT COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status = 'ABERTO';
SELECT COUNT(*) FROM tmp_perf_pedidos p JOIN tmp_perf_clientes c ON c.id_cliente = p.id_cliente WHERE c.uf = 'TO';

EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE

-- Esperado: o nome do arquivo agora inclui "tmp_estudo"
SELECT value FROM v$diag_info WHERE name = 'Default Trace File';

-- No servidor (no container: docker exec -it <container> bash), formatar com tkprof:
--   tkprof <arquivo>.trc /tmp/estudo.txt sys=no sort=exeela
-- O relatório traz, por instrução: count, cpu, elapsed, disk, query (leituras lógicas),
-- rows, o plano com as linhas reais e a lista de esperas.

-- 4. Sem os packs: o que dá para ver das esperas com as V$ incluídas.
-- Esperado: totais de espera por classe desde o início da sessão
SELECT wait_class, SUM(time_waited_micro) / 1e6 AS segundos, SUM(total_waits) AS esperas
  FROM v$session_event
 WHERE sid = SYS_CONTEXT('USERENV', 'SID')
   AND wait_class <> 'Idle'
 GROUP BY wait_class
 ORDER BY segundos DESC;

-- 5. Com Tuning Pack licenciado (não rode sem licença): relatório do SQL Monitor.
--   SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(sql_id => '...', type => 'TEXT') FROM dual;
-- Com Diagnostics Pack licenciado (não rode sem licença): ASH dos últimos 10 minutos.
--   SELECT sql_id, event, COUNT(*) FROM v$active_session_history
--    WHERE sample_time > SYSDATE - 10/1440 GROUP BY sql_id, event ORDER BY 3 DESC;
