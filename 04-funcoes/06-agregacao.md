# Funções de agregação

## Referência

| Função | Devolve | Ignora NULL |
|---|---|---|
| `COUNT(*)` | Número de linhas | Não se aplica |
| `COUNT(coluna)` | Número de valores não nulos | Sim |
| `COUNT(DISTINCT coluna)` | Número de valores distintos não nulos | Sim |
| `SUM(n)` / `AVG(n)` | Soma / média | Sim |
| `MIN(x)` / `MAX(x)` | Menor / maior; funciona com número, texto e data | Sim |
| `MEDIAN(n)` | Mediana | Sim |
| `STDDEV(n)` / `VARIANCE(n)` | Desvio padrão / variância amostral | Sim |
| `PERCENTILE_CONT(p) WITHIN GROUP (ORDER BY n)` | Percentil interpolado | Sim |
| `PERCENTILE_DISC(p) WITHIN GROUP (ORDER BY n)` | Percentil, sempre um valor existente | Sim |
| `LISTAGG(expr, sep) WITHIN GROUP (ORDER BY ...)` | Valores concatenados num texto | Sim |
| `APPROX_COUNT_DISTINCT(x)` `[12c+]` | Contagem distinta aproximada, muito mais rápida em volume grande | Sim |

Todas aceitam `DISTINCT` (exceto `COUNT(*)`), e todas podem ser usadas como **analíticas** com `OVER (...)` (tópicos 07 a 09).

## Sem linhas

Uma agregação sem `GROUP BY` sobre um conjunto vazio devolve **uma linha**: `COUNT` = 0, as demais NULL. Com `GROUP BY`, conjunto vazio devolve **nenhuma linha**.

## LISTAGG

```sql
LISTAGG([DISTINCT] expr, ', ' [ON OVERFLOW TRUNCATE '...' WITH COUNT])
    WITHIN GROUP (ORDER BY expr)
```

- `DISTINCT` `[19c+]` remove repetidos.
- O resultado é `VARCHAR2`, limitado a 4000 bytes (ou 32767 com `MAX_STRING_SIZE = EXTENDED`). Passar do limite dá **ORA-01489**.
- `ON OVERFLOW TRUNCATE` `[12.2+]` corta e acrescenta um indicador e, com `WITH COUNT`, quantos valores ficaram de fora: `'a, b, c, ...(15)'`.
- Para resultados maiores, `XMLAGG` ou `JSON_ARRAYAGG` devolvendo `CLOB`.

## KEEP (FIRST | LAST)

"O valor de uma coluna na linha com a maior (ou menor) data do grupo", sem subquery:

```sql
MAX(id_vendedor) KEEP (DENSE_RANK LAST ORDER BY data_pedido)
```

Lê-se: entre as linhas com a última `data_pedido` do grupo, o maior `id_vendedor`. A agregação de fora (`MAX`) desempata quando várias linhas têm a mesma data. Detalhado no tópico 08.

## Armadilhas

- **`AVG` ignora NULL** (tópico 05).
- **`SUM` de vazio é NULL**, não zero. Em relatório: `NVL(SUM(...), 0)`.
- **`COUNT(coluna)` em vez de `COUNT(*)`** conta só os não nulos, às vezes sem querer.
- **`MIN`/`MAX` em texto** seguem a ordem binária (`'Z' < 'a'`).
- **LISTAGG em produção** sem `ON OVERFLOW`: funciona até o dia em que um grupo cresce e a consulta passa a falhar.

## Documentação oficial

- [SQL Language Reference — Aggregate Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Aggregate-Functions.html)
- [SQL Language Reference — LISTAGG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LISTAGG.html)
