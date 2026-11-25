# Categorias de comando

## A classificação usual

| Sigla | Nome | Comandos | Para quê |
|---|---|---|---|
| DQL | Data Query Language | `SELECT` | Consultar dados |
| DML | Data Manipulation Language | `INSERT`, `UPDATE`, `DELETE`, `MERGE` | Alterar dados |
| DDL | Data Definition Language | `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME`, `COMMENT`, `PURGE`, `FLASHBACK TABLE` | Criar e alterar a estrutura |
| DCL | Data Control Language | `GRANT`, `REVOKE` | Conceder e retirar privilégios |
| TCL | Transaction Control Language | `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `SET TRANSACTION` | Controlar transações |

## A classificação da Oracle

A documentação da Oracle não usa DQL nem DCL. Ela divide os comandos em seis grupos:

| Grupo | Inclui |
|---|---|
| DDL | `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME`, `COMMENT`, **`GRANT`, `REVOKE`**, `AUDIT`, `NOAUDIT`, `ANALYZE`, `ASSOCIATE STATISTICS`, `FLASHBACK`, `PURGE` |
| DML | **`SELECT`**, `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `CALL`, `EXPLAIN PLAN`, `LOCK TABLE` |
| Controle de transação | `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `SET TRANSACTION`, `SET CONSTRAINT` |
| Controle de sessão | `ALTER SESSION`, `SET ROLE` |
| Controle de sistema | `ALTER SYSTEM` |
| SQL embutido | Comandos usados dentro de programas em outras linguagens (Pro*C, por exemplo) |

A diferença prática está em `GRANT` e `REVOKE`: para o Oracle, são DDL e têm o mesmo comportamento transacional de um `CREATE`.

## O que muda na prática: commit implícito

**Todo DDL faz commit da transação aberta antes de executar e outro commit depois.** Não existe DDL dentro de transação no Oracle, nem `ROLLBACK` de um `CREATE`, `ALTER`, `DROP` ou `TRUNCATE`.

Consequências:

- Fazer um `UPDATE`, depois um `CREATE TABLE` e depois `ROLLBACK`: o `UPDATE` já foi confirmado pelo `CREATE`.
- O commit anterior acontece **antes** de o DDL ser executado, então em geral vale mesmo quando o DDL falha (tabela inexistente num `DROP`, nome já usado num `CREATE`). Erro de sintaxe é detectado antes e não chega a disparar o commit. Não dependa de nenhum dos dois casos: confirme ou desfaça o DML antes de qualquer DDL.
- `TRUNCATE` é DDL: apaga todas as linhas sem gerar undo por linha, é muito mais rápido que `DELETE` e não tem volta com `ROLLBACK` (seção 06).
- `GRANT` no meio de uma carga confirma a carga.
- Dentro de PL/SQL, DDL só roda via SQL dinâmico (`EXECUTE IMMEDIATE`) e também confirma a transação da sessão.

Outros bancos se comportam diferente: PostgreSQL e SQL Server permitem DDL dentro de transação, com rollback (seção 14).

## Documentação oficial

- [SQL Language Reference — Types of SQL Statements](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Types-of-SQL-Statements.html)
