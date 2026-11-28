# Transações e DDL transacional

## Início e fim de transação

| | Oracle | PostgreSQL | SQL Server | MySQL (InnoDB) |
|---|---|---|---|---|
| Início | Implícito: o primeiro DML abre a transação | Cada comando é uma transação, até `BEGIN` | Cada comando é uma transação (*autocommit*), até `BEGIN TRANSACTION` | Cada comando é uma transação, até `START TRANSACTION` |
| Autocommit no cliente padrão | **Desligado** (SQL*Plus, SQL Developer) | Ligado (`psql`) | Ligado (SSMS) | Ligado (`mysql`) |
| Fim | `COMMIT` / `ROLLBACK` | `COMMIT` / `ROLLBACK` | `COMMIT` / `ROLLBACK` | `COMMIT` / `ROLLBACK` |
| Savepoint | `SAVEPOINT x` / `ROLLBACK TO x` | Idem | `SAVE TRANSACTION x` / `ROLLBACK TRANSACTION x` | Idem ao Oracle |

Quem vem de Oracle para outro banco estranha que um `UPDATE` sem `WHERE` digitado por engano não tenha volta: com autocommit, ele já foi confirmado. Quem vai no sentido contrário esquece o COMMIT e vê a outra sessão "não enxergar" o dado, ou trava linhas por horas.

## DDL dentro de transação

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| DDL faz COMMIT implícito? | **Sim**, antes e depois | Não | Não | **Sim** |
| `CREATE TABLE` pode ser desfeito com ROLLBACK? | Não | **Sim** | **Sim** | Não |
| Exceções | — | `CREATE DATABASE`, `CREATE INDEX CONCURRENTLY`, `VACUUM` não rodam em transação | Algumas operações de banco e de arquivo | Desde o 8.0, cada DDL é atômico (não fica pela metade), mas ainda confirma a transação |

No PostgreSQL e no SQL Server, um script de migração inteiro pode rodar dentro de uma transação: se o décimo comando falhar, os nove anteriores, inclusive `CREATE TABLE` e `ALTER TABLE`, são desfeitos. No Oracle e no MySQL, não: o script precisa ser pensado para ser reexecutável (`CREATE ... IF NOT EXISTS` `[23ai+]` no Oracle) ou ter um script de volta. No Oracle, Flashback Database e restore points garantidos (seção 13, tópico 09) são a rede de segurança para deploy grande.

## Erro no meio da transação

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Uma instrução falha | Só **ela** é desfeita; a transação continua | A transação inteira fica **abortada**: todo comando seguinte dá erro até o ROLLBACK | Depende: em geral só a instrução; com `SET XACT_ABORT ON`, a transação inteira | Só a instrução (na maioria dos erros) |

No PostgreSQL, depois de um erro dentro de `BEGIN ... COMMIT`, a mensagem `current transaction is aborted, commands ignored until end of transaction block` aparece para tudo. Para tratar o erro e seguir, é preciso `SAVEPOINT` antes do comando arriscado e `ROLLBACK TO SAVEPOINT` (os drivers fazem isso com opções como *autosave*). No Oracle, esse savepoint implícito por instrução já existe (seção 06, tópico 06).

No SQL Server, sem `XACT_ABORT ON`, certos erros desfazem só a instrução e deixam a transação aberta e "meio feita". A recomendação usual é `SET XACT_ABORT ON` no início de procedures que usam transação, junto com `TRY...CATCH`.

## Durabilidade e desempenho do COMMIT

Todos gravam o log de transações (redo, WAL, transaction log, redo log do InnoDB) em disco no COMMIT. Opções para relaxar a garantia em troca de velocidade existem em todos (`COMMIT WRITE NOWAIT` no Oracle, `synchronous_commit = off` no PostgreSQL, *delayed durability* no SQL Server, `innodb_flush_log_at_trx_commit` no MySQL) e são decisão de arquitetura, nunca padrão.

## Documentação

- [Oracle — Transactions](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/transactions.html)
- [PostgreSQL — Transactions](https://www.postgresql.org/docs/current/tutorial-transactions.html)
- [SQL Server — Transactions (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/language-elements/transactions-transact-sql)
- [MySQL — Statements That Cause an Implicit Commit](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html)
