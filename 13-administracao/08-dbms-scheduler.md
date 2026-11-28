# Jobs: DBMS_SCHEDULER (e DBMS_JOB `[legado]`)

O agendador do banco executa blocos PL/SQL, procedures e programas externos em horários definidos, sem depender do cron do servidor ou do agendador do Windows. Exige o privilégio `CREATE JOB` (o usuário de estudo tem).

## Criar um job

```sql
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_RECALCULA_LIMITES',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PKG_CREDITO.RECALCULAR_LIMITES',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
        enabled         => TRUE,
        comments        => 'Recalcula limites de crédito toda madrugada');
END;
/
```

| `job_type` | `job_action` |
|---|---|
| `PLSQL_BLOCK` | Um bloco `BEGIN ... END;` |
| `STORED_PROCEDURE` | Nome de procedure (parâmetros com `SET_JOB_ARGUMENT_VALUE`) |
| `EXECUTABLE` | Programa do sistema operacional (exige credencial e privilégio extra) |
| `SQL_SCRIPT` `[12c+]` | Script SQL*Plus |

## Calendário (`repeat_interval`)

| Expressão | Quando |
|---|---|
| `FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0` | Todo dia às 02:00 |
| `FREQ=WEEKLY; BYDAY=MON,WED,FRI; BYHOUR=7; BYMINUTE=30` | Segunda, quarta e sexta às 07:30 |
| `FREQ=MONTHLY; BYMONTHDAY=1; BYHOUR=6` | Dia 1 de cada mês às 06:00 |
| `FREQ=MONTHLY; BYMONTHDAY=-1` | Último dia do mês |
| `FREQ=MINUTELY; INTERVAL=15` | A cada 15 minutos |
| `FREQ=HOURLY; BYDAY=MON-FRI; BYHOUR=8-18` | De hora em hora, das 8 às 18, em dias úteis |

`DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING` calcula as próximas datas de uma expressão sem criar job: a forma de testar o calendário antes de confiar nele. O fuso horário vem do `start_date`; use `TIMESTAMP WITH TIME ZONE` (`SYSTIMESTAMP`) para o horário de verão não deslocar a execução.

## Acompanhar

| Visão | Mostra |
|---|---|
| `USER_SCHEDULER_JOBS` | Jobs, estado (`ENABLED`), `STATE` (`SCHEDULED`, `RUNNING`, `DISABLED`, `BROKEN`), `NEXT_RUN_DATE`, `LAST_START_DATE`, `FAILURE_COUNT` |
| `USER_SCHEDULER_JOB_RUN_DETAILS` | Cada execução: início, duração, `STATUS` (`SUCCEEDED`, `FAILED`), `ERROR#` e `ADDITIONAL_INFO` com a mensagem de erro |
| `USER_SCHEDULER_JOB_LOG` | Eventos do job (criado, executado, alterado) |
| `USER_SCHEDULER_RUNNING_JOBS` | O que está rodando agora |

## Operar

| Rotina | Faz |
|---|---|
| `RUN_JOB(nome, use_current_session => TRUE)` | Executa agora, na sessão atual (erro aparece na tela) |
| `ENABLE` / `DISABLE` | Liga e desliga |
| `STOP_JOB` | Interrompe uma execução em curso |
| `SET_ATTRIBUTE` | Muda horário, ação, número de tentativas (`max_failures`, `max_runs`) |
| `DROP_JOB` | Remove |

## Boas práticas

- O código do job vai numa **procedure** (ou package), não num bloco grande no `job_action`: versionável, testável, compilado.
- A procedure registra início, fim e erro numa tabela de log com transação autônoma (seção 09, tópico 12), além do registro do agendador.
- Erro não tratado marca a execução como `FAILED`, e o job continua agendado. Depois de `max_failures` falhas seguidas, fica `BROKEN`. Monitore `FAILURE_COUNT`.
- O job roda com os privilégios do dono, **sem roles**, como uma procedure DEFINER (seção 09, tópico 14).
- Jobs param quando o parâmetro `JOB_QUEUE_PROCESSES` é 0 (comum em bancos restaurados para teste, de propósito).

## DBMS_JOB `[legado]`

A API antiga (`DBMS_JOB.SUBMIT`, intervalo como expressão de data: `'SYSDATE + 1/24'`). A partir do 19c, os jobs criados por ela são convertidos em jobs do Scheduler. Mantenha só para ler código antigo.

## Documentação oficial

- [Database Administrator's Guide — Scheduling Jobs with Oracle Scheduler](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/scheduling-jobs-with-oracle-scheduler.html)
- [PL/SQL Packages and Types Reference — DBMS_SCHEDULER](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SCHEDULER.html)
