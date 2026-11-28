# Ferramentas: AUTOTRACE, SQL trace, SQL Monitor, AWR, ASH e licenciamento

## O que cada ferramenta responde

| Ferramenta | Responde | Licença |
|---|---|---|
| `DBMS_XPLAN.DISPLAY` / `DISPLAY_CURSOR` (tópicos 02 e 03) | Plano previsto e plano real com linhas por etapa | Incluída |
| **AUTOTRACE** do SQL*Plus / SQLcl | Plano e estatísticas de execução (leituras lógicas, físicas, redo, ordenações) de cada instrução que você roda | Incluída |
| **SQL trace** (`DBMS_MONITOR`, evento 10046) + **TKPROF** | Tudo o que uma sessão fez: cada SQL, execuções, fetches, tempos e **esperas** | Incluída. Exige acesso aos arquivos de trace no servidor |
| `V$SESSION`, `V$SQL`, `V$SESSION_WAIT` (seção 10, tópico 09) | O que está acontecendo agora | Incluídas |
| **Statspack** | Fotos periódicas das estatísticas da instância e relatório entre duas fotos | Incluída; instalada pelo DBA |
| **AWR** e **ADDM** | O mesmo que o Statspack, automático, com histórico e diagnóstico | **Diagnostics Pack** |
| **ASH** (`V$ACTIVE_SESSION_HISTORY`, `DBA_HIST_ACTIVE_SESS_HISTORY`) | Amostra por segundo de cada sessão ativa: "o que estava rodando às 10h15?" | **Diagnostics Pack** |
| **SQL Monitor** (`DBMS_SQLTUNE.REPORT_SQL_MONITOR`, `V$SQL_MONITOR`) | Execução de uma instrução longa ou paralela em tempo real, etapa por etapa | **Tuning Pack** |
| SQL Tuning Advisor, SQL Profiles | Recomendações automáticas de ajuste | **Tuning Pack** |

## Licenciamento

O Diagnostics Pack e o Tuning Pack são **licenças à parte**, vendidas só para a Enterprise Edition. Segundo a documentação de licenciamento da Oracle:

- AWR, ASH e os relatórios de carga exigem licença do **Diagnostics Pack**; a visão `V$ACTIVE_SESSION_HISTORY` (e a tabela interna por trás dela) faz parte desse pack.
- O **Tuning Pack** só pode ser licenciado junto com o Diagnostics Pack.
- O parâmetro `CONTROL_MANAGEMENT_PACK_ACCESS` controla o acesso aos dois: `DIAGNOSTIC+TUNING` (os dois habilitados), `DIAGNOSTIC` (só o Diagnostics) ou `NONE` (nenhum).

Na prática:

- O banco **não impede** a consulta a `V$ACTIVE_SESSION_HISTORY` ou a geração de um relatório AWR quando o parâmetro está ligado. O uso fica registrado em `DBA_FEATURE_USAGE_STATISTICS` e aparece numa auditoria de licenças.
- Antes de usar AWR, ASH ou SQL Monitor num banco de empresa, confirme com o DBA ou com o responsável pelos contratos se os packs estão licenciados. Se não estiverem, o caminho é Statspack, SQL trace com TKPROF, `DISPLAY_CURSOR` e as `V$` comuns.
- Standard Edition 2 não permite licenciar os packs.
- Edições gratuitas (Oracle Database Free) e serviços em nuvem têm regras próprias: confira o manual de licenciamento da versão em uso, porque elas mudam com o tempo.

## AUTOTRACE

| Comando | Mostra |
|---|---|
| `SET AUTOTRACE ON` | Resultado, plano e estatísticas |
| `SET AUTOTRACE TRACEONLY` | Plano e estatísticas, sem as linhas |
| `SET AUTOTRACE TRACEONLY STATISTICS` | Só as estatísticas |
| `SET AUTOTRACE OFF` | Desliga |

As estatísticas mais úteis: `consistent gets` (leituras lógicas: a medida de trabalho), `physical reads`, `sorts (disk)` (ordenação que não coube em memória), `rows processed`. Executa a instrução de verdade, inclusive DML. O plano mostrado é o do `EXPLAIN PLAN` (com as mesmas limitações do tópico 02) em versões antigas do SQL*Plus; nas recentes, é o do cursor executado.

## SQL trace e TKPROF

```sql
EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(waits => TRUE, binds => FALSE)

-- executar o processo

EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE
```

O arquivo vai para o diretório de trace do servidor (`V$DIAG_INFO`, linha `Default Trace File`). O `tkprof` (linha de comando no servidor) agrupa por instrução e mostra o tempo total, as execuções e as esperas. É a ferramenta certa para "o processo noturno demora 3 horas, onde está o tempo?", sem licença adicional. Exige acesso ao sistema de arquivos do servidor, normalmente via DBA.

## Documentação oficial

- [Database Licensing Information User Manual 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/dblic/Licensing-Information.html)
- [SQL*Plus User's Guide — Tuning SQL*Plus: AUTOTRACE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/tuning-SQL-Plus.html)
- [SQL Tuning Guide — Performing Application Tracing](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/performing-application-tracing.html)
- [SQL Tuning Guide — Monitoring Database Operations](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/monitoring-database-operations.html)
