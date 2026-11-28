-- =============================================================================
-- Tópico : DBMS_SCHEDULER — testar calendário, job que roda uma vez, job que
--          falha, acompanhar execuções, job repetitivo
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE JOB e CREATE PROCEDURE
--          (concedidos em 00-ambiente); JOB_QUEUE_PROCESSES maior que 0
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
COLUMN job_name        FORMAT A26
COLUMN status          FORMAT A10
COLUMN additional_info FORMAT A60 TRUNCATED

-- 0. O agendador está ligado?
-- Esperado: job_queue_processes maior que 0 (o padrão é alto)
SELECT name, value FROM v$parameter WHERE name = 'job_queue_processes';

-- 1. Testar uma expressão de calendário sem criar job.
DECLARE
    v_inicio  TIMESTAMP WITH TIME ZONE := TIMESTAMP '2026-11-27 08:00:00 -03:00';
    v_depois  TIMESTAMP WITH TIME ZONE := v_inicio;
    v_proxima TIMESTAMP WITH TIME ZONE;
BEGIN
    FOR i IN 1 .. 5 LOOP
        DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
            calendar_string   => 'FREQ=WEEKLY; BYDAY=MON,WED,FRI; BYHOUR=7; BYMINUTE=30; BYSECOND=0',
            start_date        => v_inicio,
            return_date_after => v_depois,
            next_run_date     => v_proxima);
        DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_proxima, 'Dy DD/MM/YYYY HH24:MI', 'NLS_DATE_LANGUAGE = PORTUGUESE'));
        v_depois := v_proxima;
    END LOOP;
END;
/
-- Esperado (a partir de sexta 27/11/2026 08:00):
--   Seg 30/11/2026 07:30
--   Qua 02/12/2026 07:30
--   Sex 04/12/2026 07:30
--   Seg 07/12/2026 07:30
--   Qua 09/12/2026 07:30

-- Último dia útil de cada mês? O calendário permite: dias úteis do mês, o último deles.
DECLARE
    v_inicio  TIMESTAMP WITH TIME ZONE := TIMESTAMP '2026-11-27 08:00:00 -03:00';
    v_depois  TIMESTAMP WITH TIME ZONE := v_inicio;
    v_proxima TIMESTAMP WITH TIME ZONE;
BEGIN
    FOR i IN 1 .. 3 LOOP
        DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
            'FREQ=MONTHLY; BYDAY=MON,TUE,WED,THU,FRI; BYSETPOS=-1; BYHOUR=18; BYMINUTE=0; BYSECOND=0',
            v_inicio, v_depois, v_proxima);
        DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_proxima, 'Dy DD/MM/YYYY HH24:MI', 'NLS_DATE_LANGUAGE = PORTUGUESE'));
        v_depois := v_proxima;
    END LOOP;
END;
/
-- Esperado: Seg 30/11/2026 18:00 | Qui 31/12/2026 18:00 | Sex 29/01/2027 18:00

-- 2. A rotina que o job vai executar, com log.
CREATE TABLE tmp_log_job (
    momento TIMESTAMP DEFAULT SYSTIMESTAMP,
    texto   VARCHAR2(200)
);

CREATE OR REPLACE PROCEDURE tmp_proc_resumo_diario (p_falhar IN VARCHAR2 DEFAULT 'N') IS
    v_qtd NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_qtd FROM pedidos WHERE status = 'ABERTO';
    INSERT INTO tmp_log_job (texto) VALUES ('pedidos abertos: ' || v_qtd);
    COMMIT;

    IF p_falhar = 'S' THEN
        RAISE_APPLICATION_ERROR(-20801, 'Falha simulada no job');
    END IF;
END tmp_proc_resumo_diario;
/

-- 3. Job que roda uma vez, agora.
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name   => 'TMP_JOB_UMA_VEZ',
        job_type   => 'STORED_PROCEDURE',
        job_action => 'TMP_PROC_RESUMO_DIARIO',
        start_date => SYSTIMESTAMP,
        enabled    => TRUE,
        auto_drop  => TRUE,
        comments   => 'Exemplo da seção 13');
END;
/

-- Esperar o job rodar (alguns segundos).
EXEC DBMS_SESSION.SLEEP(5)

-- Esperado: uma linha "pedidos abertos: 3"
SELECT momento, texto FROM tmp_log_job ORDER BY momento;

-- O job se apagou sozinho (auto_drop), mas o histórico fica.
-- Esperado: TMP_JOB_UMA_VEZ | SUCCEEDED
SELECT job_name, status, actual_start_date, run_duration
  FROM user_scheduler_job_run_details
 WHERE job_name = 'TMP_JOB_UMA_VEZ'
 ORDER BY actual_start_date DESC;

-- 4. Job com parâmetro que falha.
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name            => 'TMP_JOB_FALHA',
        job_type            => 'STORED_PROCEDURE',
        job_action          => 'TMP_PROC_RESUMO_DIARIO',
        number_of_arguments => 1,
        enabled             => FALSE,
        auto_drop           => FALSE);
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('TMP_JOB_FALHA', 1, 'S');
    DBMS_SCHEDULER.ENABLE('TMP_JOB_FALHA');
END;
/

EXEC DBMS_SESSION.SLEEP(5)

-- Esperado: TMP_JOB_FALHA | FAILED | error# 20801 | ORA-20801: Falha simulada no job ...
SELECT job_name, status, error#, additional_info
  FROM user_scheduler_job_run_details
 WHERE job_name = 'TMP_JOB_FALHA'
 ORDER BY actual_start_date DESC;

-- 5. RUN_JOB na sessão atual: o erro aparece na tela (bom para testar).
BEGIN
    DBMS_SCHEDULER.RUN_JOB('TMP_JOB_FALHA', use_current_session => TRUE);
END;
/
-- Esperado: ORA-20801: Falha simulada no job

BEGIN
    DBMS_SCHEDULER.DROP_JOB('TMP_JOB_FALHA', force => TRUE);
END;
/

-- 6. Job repetitivo, criado desligado (para não ficar rodando no ambiente de estudo).
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'TMP_JOB_DIARIO',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'TMP_PROC_RESUMO_DIARIO',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
        enabled         => FALSE,
        comments        => 'Resumo diário às 02:00');
END;
/

-- Esperado: TMP_JOB_DIARIO | enabled FALSE | state DISABLED | o calendário
SELECT job_name, enabled, state, repeat_interval, next_run_date, failure_count
  FROM user_scheduler_jobs
 WHERE job_name LIKE 'TMP%';

-- Ligado, a próxima execução fica calculada.
EXEC DBMS_SCHEDULER.ENABLE('TMP_JOB_DIARIO')

-- Esperado: state SCHEDULED | next_run_date na próxima madrugada, às 02:00
SELECT job_name, enabled, state, next_run_date FROM user_scheduler_jobs WHERE job_name = 'TMP_JOB_DIARIO';

-- Limpeza.
EXEC DBMS_SCHEDULER.DROP_JOB('TMP_JOB_DIARIO')
DROP PROCEDURE tmp_proc_resumo_diario;
DROP TABLE tmp_log_job PURGE;

-- O histórico de execução continua em USER_SCHEDULER_JOB_RUN_DETAILS até a limpeza
-- automática (padrão: 30 dias). Para apagar já o histórico destes exemplos:
--   EXEC DBMS_SCHEDULER.PURGE_LOG(job_name => 'TMP_JOB_UMA_VEZ, TMP_JOB_FALHA, TMP_JOB_DIARIO')
