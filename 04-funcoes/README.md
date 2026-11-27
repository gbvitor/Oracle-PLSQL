# 04 — Funções

Funções nativas do Oracle agrupadas por finalidade, com os formatos e parâmetros que mais aparecem no dia a dia.

## Tópicos

### Funções de linha

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Texto: SUBSTR, INSTR, TRIM, LPAD, REPLACE, TRANSLATE, tirar acentos | [md](01-texto.md) | [sql](01-texto.sql) |
| 02 | Numéricas: ROUND, TRUNC, CEIL, FLOOR, MOD, WIDTH_BUCKET, rateio | [md](02-numericas.md) | [sql](02-numericas.sql) |
| 03 | Data e hora: EXTRACT, NEXT_DAY, ROUND/TRUNC de data, fuso horário | [md](03-data-e-hora.md) | [sql](03-data-e-hora.sql) |
| 04 | Conversão: TO_CHAR, TO_DATE, TO_NUMBER, CAST, máscaras, conversão tolerante a erro | [md](04-conversao.md) | [sql](04-conversao.sql) |
| 05 | NULL: NVL, NVL2, COALESCE, NULLIF, LNNVL | [md](05-tratamento-de-null.md) | [sql](05-tratamento-de-null.sql) |

### Agregação e analíticas

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 06 | Agregação: COUNT, SUM, AVG, MEDIAN, percentis, LISTAGG, KEEP | [md](06-agregacao.md) | [sql](06-agregacao.sql) |
| 07 | Analíticas I: ROW_NUMBER, RANK, DENSE_RANK, NTILE; top-N por grupo; deduplicação | [md](07-analiticas-ranking.md) | [sql](07-analiticas-ranking.sql) |
| 08 | Analíticas II: LAG, LEAD, FIRST_VALUE, LAST_VALUE, NTH_VALUE, IGNORE NULLS | [md](08-analiticas-lag-lead.md) | [sql](08-analiticas-lag-lead.sql) |
| 09 | Analíticas III: janelas ROWS/RANGE, acumulados, médias móveis, RATIO_TO_REPORT | [md](09-analiticas-janelas.md) | [sql](09-analiticas-janelas.sql) |

### Texto estruturado e outras

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 10 | Expressões regulares: REGEXP_SUBSTR, REGEXP_INSTR, REGEXP_REPLACE, REGEXP_COUNT | [md](10-expressoes-regulares.md) | [sql](10-expressoes-regulares.sql) |
| 11 | JSON: JSON_OBJECT, JSON_ARRAYAGG, JSON_VALUE, JSON_QUERY, JSON_TABLE | [md](11-json.md) | [sql](11-json.sql) |
| 12 | GREATEST, LEAST, SYS_GUID, ORA_HASH, STANDARD_HASH, SYS_CONTEXT, DUMP, DBMS_RANDOM | [md](12-outras.md) | [sql](12-outras.sql) |

## Observações

- Os tópicos 03 e 04 alteram parâmetros NLS da sessão para que os resultados esperados valham em qualquer ferramenta; o fim de cada script volta a um padrão conhecido.
- Valores monetários usam o valor líquido do item, arredondado a 2 casas, sem pedidos cancelados.
