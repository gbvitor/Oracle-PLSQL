# Visões dinâmicas V$: V$SESSION, V$SQL, V$LOCK

As visões `V$` mostram o estado **atual da instância**: quem está conectado, o que cada sessão está fazendo, que SQL está em memória, quem trava quem. Os dados vêm de estruturas em memória e somem quando a instância reinicia (ou quando o SQL sai do cache).

Acesso: `SELECT_CATALOG_ROLE` ou `SELECT ANY DICTIONARY`. O nome público `V$SESSION` é sinônimo da visão `SYS.V_$SESSION`; grants diretos são dados em `V_$SESSION`. Em RAC, `GV$` traz todas as instâncias com a coluna `INST_ID`.

## As mais usadas

| Visão | Mostra | Colunas-chave |
|---|---|---|
| `V$SESSION` | Uma linha por sessão | `SID`, `SERIAL#`, `USERNAME`, `STATUS`, `OSUSER`, `MACHINE`, `PROGRAM`, `MODULE`, `ACTION`, `SQL_ID`, `EVENT`, `WAIT_CLASS`, `BLOCKING_SESSION`, `LOGON_TIME`, `LAST_CALL_ET` |
| `V$SQL` | Uma linha por cursor filho em memória | `SQL_ID`, `CHILD_NUMBER`, `SQL_TEXT`, `SQL_FULLTEXT`, `EXECUTIONS`, `ELAPSED_TIME` e `CPU_TIME` (microssegundos), `BUFFER_GETS`, `DISK_READS`, `ROWS_PROCESSED`, `PLAN_HASH_VALUE`, `PARSING_SCHEMA_NAME`, `LAST_ACTIVE_TIME` |
| `V$SQLAREA` | O mesmo agregado por `SQL_ID` | |
| `V$LOCK` | Travas mantidas e pedidas | `SID`, `TYPE` (`TX` linha, `TM` tabela), `LMODE`, `REQUEST`, `BLOCK` |
| `V$LOCKED_OBJECT` | Objetos com trava por sessão | `SESSION_ID`, `OBJECT_ID`, `LOCKED_MODE` |
| `V$SESSION_LONGOPS` | Operações longas com progresso | `SOFAR`, `TOTALWORK`, `TIME_REMAINING` |
| `V$MYSTAT` + `V$STATNAME` | Estatísticas da própria sessão | `session logical reads`, `redo size`... |
| `V$PARAMETER` | Parâmetros de inicialização em vigor | `NAME`, `VALUE`, `ISDEFAULT` |
| `V$VERSION`, `V$INSTANCE`, `V$DATABASE` | Versão, instância, banco | |

## Ler V$SESSION

- `STATUS = 'ACTIVE'`: executando uma chamada agora. `INACTIVE`: conectada, parada esperando o cliente.
- `EVENT` e `WAIT_CLASS`: o que a sessão está esperando. `WAIT_CLASS = 'Idle'` é espera normal (cliente não mandou nada); `enq: TX - row lock contention` é espera por linha travada por outra sessão.
- `BLOCKING_SESSION`: o `SID` de quem está travando esta sessão. É o atalho para "quem está me bloqueando?" sem montar o JOIN em `V$LOCK`.
- `LAST_CALL_ET`: segundos desde a última mudança de estado. Em sessão ACTIVE, há quanto tempo a chamada atual está rodando.
- `SID` + `SERIAL#` identificam a sessão para `ALTER SYSTEM KILL SESSION` (seção 13, tópico 06).

## Ler V$SQL

- Tempos em **microssegundos**, acumulados desde que o cursor entrou em memória. Divida por `EXECUTIONS` para ter a média por execução.
- `BUFFER_GETS` (leituras lógicas) é a melhor medida de "trabalho" de uma consulta: não depende do cache estar quente.
- `SQL_TEXT` corta em 1000 caracteres; `SQL_FULLTEXT` (CLOB) tem o texto inteiro.
- O plano do cursor: `DBMS_XPLAN.DISPLAY_CURSOR(sql_id, child_number)` (seção 11, tópico 03).

## Licenciamento

`V$SESSION`, `V$SQL`, `V$LOCK` e as demais `V$` comuns fazem parte do banco. Já `V$ACTIVE_SESSION_HISTORY`, as visões `DBA_HIST_*` (AWR) e os relatórios AWR/ASH exigem o **Diagnostics Pack**, licença à parte da Enterprise Edition. Consultá-las sem licença é uso não licenciado, mesmo que o banco permita. O parâmetro `CONTROL_MANAGEMENT_PACK_ACCESS` indica o que está habilitado.

## Documentação oficial

- [Database Reference — Dynamic Performance Views](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/dynamic-performance-views.html)
- [Database Reference — V$SESSION](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-SESSION.html)
- [Database Reference — V$SQL](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-SQL.html)
- [Database Licensing Information — Diagnostics Pack](https://docs.oracle.com/en/database/oracle/oracle-database/19/dblic/Licensing-Information.html)
