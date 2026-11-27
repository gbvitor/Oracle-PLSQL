# 05 — Consultas

Combinação das cláusulas, expressões e funções para resolver perguntas reais sobre os dados. Os tópicos são organizados por problema.

## Tópicos

### Joins

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | INNER JOIN: várias tabelas, desigualdade, granularidade, FK nula | [md](01-inner-join.md) | [sql](01-inner-join.sql) |
| 02 | LEFT, RIGHT e FULL OUTER JOIN; condição no ON versus no WHERE | [md](02-outer-join.md) | [sql](02-outer-join.sql) |
| 03 | CROSS JOIN, self join, NATURAL JOIN e USING | [md](03-cross-self-natural-using.md) | [sql](03-cross-self-natural-using.sql) |
| 04 | Sintaxe antiga com `(+)` e como converter para ANSI `[legado]` | [md](04-join-legado.md) | [sql](04-join-legado.sql) |

### Subqueries e conjuntos

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 05 | Subqueries: tipos, correlação, várias colunas, HAVING, DML | [md](05-subqueries.md) | [sql](05-subqueries.sql) |
| 06 | UNION, UNION ALL, INTERSECT, MINUS; comparar tabelas | [md](06-operadores-de-conjunto.md) | [sql](06-operadores-de-conjunto.sql) |

### Problemas recorrentes

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 07 | Último registro e top-N por grupo: cinco formas comparadas; vigência | [md](07-ultimo-e-top-n-por-grupo.md) | [sql](07-ultimo-e-top-n-por-grupo.sql) |
| 08 | Encontrar e remover duplicidades | [md](08-duplicidades.md) | [sql](08-duplicidades.sql) |
| 09 | Lacunas e sequências (gaps and islands) | [md](09-gaps-and-islands.md) | [sql](09-gaps-and-islands.sql) |
| 10 | LATERAL, CROSS APPLY e OUTER APPLY | [md](10-lateral-apply.md) | [sql](10-lateral-apply.sql) |

## Assuntos tratados em outras seções

| Assunto | Onde |
|---|---|
| Paginação e top-N simples | [02 — Cláusulas, tópico 07](../02-clausulas/07-fetch-offset.md) |
| Hierarquias (organograma, árvore de categorias) | [02 — Cláusulas, tópicos 08 e 09](../02-clausulas/09-connect-by.md) |
| Linhas para colunas e colunas para linhas | [02 — Cláusulas, tópico 10](../02-clausulas/10-pivot-unpivot.md) |
| Subquery escalar | [03 — Expressões, tópico 05](../03-expressoes-e-condicoes/05-subquery-escalar.md) |
| EXISTS, IN e NOT IN | [03 — Expressões, tópicos 09 e 12](../03-expressoes-e-condicoes/12-exists.md) |
