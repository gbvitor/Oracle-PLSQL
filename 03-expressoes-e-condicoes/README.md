# 03 — Expressões e condições

Como o Oracle calcula valores e avalia filtros: operadores, precedência, expressões condicionais e as condições usadas em WHERE, HAVING, CASE e PL/SQL.

## Tópicos

### Expressões

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Operadores aritméticos, concatenação e precedência | [md](01-operadores-e-precedencia.md) | [sql](01-operadores-e-precedencia.sql) |
| 02 | CASE simples e pesquisado; agregação condicional | [md](02-case.md) | [sql](02-case.sql) |
| 03 | DECODE e as diferenças em relação ao CASE | [md](03-decode.md) | [sql](03-decode.sql) |
| 04 | Datas e intervalos: aritmética, ADD_MONTHS, INTERVAL, TRUNC | [md](04-datas-e-intervalos.md) | [sql](04-datas-e-intervalos.sql) |
| 05 | Subquery escalar | [md](05-subquery-escalar.md) | [sql](05-subquery-escalar.sql) |
| 06 | Conversão implícita de tipos | [md](06-conversao-implicita.md) | [sql](06-conversao-implicita.sql) |

### Condições

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 07 | Comparação: `=`, `<>`, ANY, SOME, ALL | [md](07-comparacao-any-all.md) | [sql](07-comparacao-any-all.sql) |
| 08 | AND, OR, NOT, IS NULL, LNNVL e parênteses | [md](08-logica-e-null.md) | [sql](08-logica-e-null.sql) |
| 09 | IN e NOT IN (a armadilha do NULL, o limite de 1000) | [md](09-in-not-in.md) | [sql](09-in-not-in.sql) |
| 10 | BETWEEN (limites inclusivos, datas, texto) | [md](10-between.md) | [sql](10-between.sql) |
| 11 | LIKE, curingas e ESCAPE | [md](11-like-escape.md) | [sql](11-like-escape.sql) |
| 12 | EXISTS e NOT EXISTS | [md](12-exists.md) | [sql](12-exists.sql) |
| 13 | REGEXP_LIKE | [md](13-regexp-like.md) | [sql](13-regexp-like.sql) |

## Observações

- Alguns scripts alteram parâmetros NLS da sessão (`NLS_DATE_FORMAT`, `NLS_NUMERIC_CHARACTERS`) para mostrar o efeito da configuração. Os valores voltam a um padrão conhecido no fim, mas abrir uma sessão nova restaura a configuração original da ferramenta.
- Os scripts que alteram dados terminam em `ROLLBACK`; os que criam objetos os removem.
