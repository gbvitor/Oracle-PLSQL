# 06 — DML e transações

Alteração de dados e controle de transação: o que fica visível para quem, quando os locks aparecem e como desfazer.

## Tópicos

### Comandos DML

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | INSERT: VALUES, SELECT, DEFAULT, IDENTITY, carga direta | [md](01-insert.md) | [sql](01-insert.sql) |
| 02 | INSERT ALL e INSERT FIRST | [md](02-insert-all-first.md) | [sql](02-insert-all-first.sql) |
| 03 | UPDATE: várias colunas, a partir de outra tabela, key-preserved | [md](03-update.md) | [sql](03-update.sql) |
| 04 | DELETE e TRUNCATE | [md](04-delete-truncate.md) | [sql](04-delete-truncate.sql) |
| 05 | MERGE: upsert, DELETE WHERE, ORA-30926 | [md](05-merge.md) | [sql](05-merge.sql) |
| 10 | DML error logging (LOG ERRORS) | [md](10-dml-error-logging.md) | [sql](10-dml-error-logging.sql) |

### Transações e concorrência

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 06 | COMMIT, ROLLBACK, SAVEPOINT, atomicidade por comando | [md](06-transacoes.md) | [sql](06-transacoes.sql) |
| 07 | Consistência de leitura e UNDO (duas sessões) | [md](07-consistencia-de-leitura.md) | [sql](07-consistencia-de-leitura.sql) |
| 08 | Locks, deadlock e FK sem índice (duas sessões) | [md](08-locks.md) | [sql](08-locks.sql) |
| 09 | Níveis de isolamento: READ COMMITTED, SERIALIZABLE, READ ONLY (duas sessões) | [md](09-isolamento.md) | [sql](09-isolamento.sql) |

## Observações

- O commit implícito do DDL está na [seção 01, tópico 10](../01-fundamentos/10-categorias-de-comando.md).
- `FOR UPDATE`, `NOWAIT` e `SKIP LOCKED` estão na [seção 02, tópico 11](../02-clausulas/11-for-update.md).
- Os tópicos 07, 08 e 09 precisam de duas sessões abertas ao mesmo tempo; os blocos indicam em qual sessão rodar cada comando.
- O tópico 04 usa `COLUMN ... NEW_VALUE` do SQL*Plus/SQLcl no último exemplo.
