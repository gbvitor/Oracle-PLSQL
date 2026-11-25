# 02 — Cláusulas

Cada cláusula do SELECT e dos comandos de manipulação, isolada: para que serve, a sintaxe completa e o que acontece em casos de borda.

## Tópicos

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | SELECT e DISTINCT; aliases de coluna | [md](01-select-distinct.md) | [sql](01-select-distinct.sql) |
| 02 | FROM: tabelas, aliases, inline views, coleções, LATERAL | [md](02-from.md) | [sql](02-from.sql) |
| 03 | WHERE: precedência, datas, índice, conversão implícita | [md](03-where.md) | [sql](03-where.sql) |
| 04 | GROUP BY, ROLLUP, CUBE, GROUPING SETS, GROUPING() | [md](04-group-by.md) | [sql](04-group-by.sql) |
| 05 | HAVING e a diferença para WHERE | [md](05-having.md) | [sql](05-having.sql) |
| 06 | ORDER BY: NULLS FIRST/LAST, desempate, ordem personalizada, texto | [md](06-order-by.md) | [sql](06-order-by.sql) |
| 07 | FETCH FIRST / OFFSET, WITH TIES, paginação, ROWNUM | [md](07-fetch-offset.md) | [sql](07-fetch-offset.sql) |
| 08 | WITH (CTE), WITH recursivo, SEARCH, CYCLE, WITH FUNCTION | [md](08-with.md) | [sql](08-with.sql) |
| 09 | CONNECT BY, PRIOR, LEVEL, SYS_CONNECT_BY_PATH, CONNECT_BY_ROOT | [md](09-connect-by.md) | [sql](09-connect-by.sql) |
| 10 | PIVOT e UNPIVOT | [md](10-pivot-unpivot.md) | [sql](10-pivot-unpivot.sql) |
| 11 | FOR UPDATE, NOWAIT, WAIT, SKIP LOCKED (duas sessões) | [md](11-for-update.md) | [sql](11-for-update.sql) |
| 12 | RETURNING INTO em INSERT, UPDATE e DELETE | [md](12-returning-into.md) | [sql](12-returning-into.sql) |
| 13 | SAMPLE e Flashback Query (AS OF) | [md](13-sample-e-flashback-query.md) | [sql](13-sample-e-flashback-query.sql) |
| 14 | MATCH_RECOGNIZE (padrões em sequências de linhas) | [md](14-match-recognize.md) | [sql](14-match-recognize.sql) |
| 15 | MODEL (visão geral) | [md](15-model.md) | [sql](15-model.sql) |

## Observações

- Valores monetários usam o valor líquido do item: `quantidade * preco_unitario * (1 - pct_desconto / 100)`, arredondado a 2 casas, sem pedidos cancelados.
- O tópico 11 precisa de duas sessões abertas ao mesmo tempo.
- Os tópicos 12 e 13 usam comandos do SQL*Plus/SQLcl (`VARIABLE`, `PRINT`, `COLUMN ... NEW_VALUE`); no FreeSQL, esses trechos não funcionam.
