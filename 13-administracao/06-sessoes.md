# Sessões: identificar, monitorar e encerrar

As colunas de `V$SESSION` estão descritas na seção 10 (tópico 09). Aqui, o roteiro de quem precisa responder "quem está no banco, o que está fazendo e como paro isso".

## Identificar

| Pergunta | Colunas |
|---|---|
| Quem é | `USERNAME` (usuário do banco), `OSUSER`, `MACHINE`, `PROGRAM`, `MODULE`, `CLIENT_IDENTIFIER` |
| Desde quando | `LOGON_TIME` |
| O que está fazendo | `STATUS`, `SQL_ID`, `EVENT`, `WAIT_CLASS`, `LAST_CALL_ET`, `ACTION` |
| Qual é o processo | `SID` + `SERIAL#` (a sessão), `V$PROCESS.SPID` (o processo do sistema operacional, ligado por `PADDR = ADDR`) |

Aplicações que usam pool de conexões aparecem todas com o mesmo usuário e a mesma máquina (o servidor de aplicação). Para saber **qual usuário da aplicação** está por trás de cada sessão, a aplicação precisa preencher `CLIENT_IDENTIFIER` (`DBMS_SESSION.SET_IDENTIFIER`) e `MODULE`/`ACTION` (`DBMS_APPLICATION_INFO`, seção 09, tópico 16). Vale exigir isso de quem desenvolve.

## Monitorar

- Sessões ativas, ordenadas por `LAST_CALL_ET`: o que está rodando há mais tempo.
- `V$SESSION_LONGOPS`: operações longas (leitura completa de tabela grande, ordenação, backup) com `SOFAR`, `TOTALWORK` e `TIME_REMAINING`.
- `V$SQL` pelo `SQL_ID` da sessão: o texto e o plano (`DBMS_XPLAN.DISPLAY_CURSOR`, seção 11, tópico 03).
- `V$SESS_IO` e `V$SESSTAT`: leituras e outras estatísticas por sessão.

## Encerrar

```sql
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
ALTER SYSTEM DISCONNECT SESSION 'sid,serial#' IMMEDIATE;
```

- Exige o privilégio `ALTER SYSTEM`.
- A sessão encerrada tem a transação **desfeita**. Desfazer pode demorar tanto quanto a transação levou para fazer: uma carga de duas horas encerrada no fim leva perto de duas horas de rollback, com os locks mantidos até terminar. Matar não é atalho para liberar um bloqueio grande.
- Sem `IMMEDIATE`, a sessão fica com `STATUS = 'KILLED'` até o cliente fazer a próxima chamada.
- Em RAC, `'sid,serial#,@inst_id'`.
- `[18c+]` `ALTER SYSTEM CANCEL SQL 'sid,serial#'` cancela **só a instrução em curso**, sem derrubar a sessão. Para uma consulta que travou o servidor de relatórios, é a opção mais gentil.
- Pela própria sessão, `Ctrl+C` no SQL*Plus cancela a instrução atual (ORA-01013).

Encerrar a sessão do sistema operacional (`kill -9` no processo) é último recurso: o PMON limpa depois, mas no Windows e com servidores compartilhados o comportamento é outro.

## Documentação oficial

- [Database Administrator's Guide — Terminating Sessions](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-processes.html)
- [SQL Language Reference — ALTER SYSTEM (KILL SESSION, CANCEL SQL)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ALTER-SYSTEM.html)
- [Database Reference — V$SESSION](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-SESSION.html)
