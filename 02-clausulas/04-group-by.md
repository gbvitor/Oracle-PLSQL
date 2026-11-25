# GROUP BY

## O que faz

Junta as linhas que têm o mesmo valor nas colunas (ou expressões) do `GROUP BY` e devolve **uma linha por grupo**. As funções de agregação (`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `LISTAGG`...) calculam um valor para cada grupo.

```sql
SELECT status, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY status;
```

## A regra das colunas

Toda coluna da lista de seleção que **não** está dentro de uma agregação precisa estar no `GROUP BY`. Caso contrário: ORA-00979 (não é uma expressão GROUP BY).

```sql
-- ORA-00979: nome não está agrupado nem agregado
SELECT id_cliente, nome, COUNT(*) FROM ... GROUP BY id_cliente;
```

O contrário é permitido: agrupar por uma coluna que não aparece no `SELECT`.

## Agrupar por expressão

```sql
SELECT TO_CHAR(data_pedido, 'YYYY-MM') AS competencia, COUNT(*)
  FROM pedidos
 GROUP BY TO_CHAR(data_pedido, 'YYYY-MM');
```

A expressão do `SELECT` precisa ser igual à do `GROUP BY`. No 19c não dá para usar o alias (`GROUP BY competencia`); `[23ai+]` permite.

## Subtotais: ROLLUP, CUBE e GROUPING SETS

Extensões que geram, numa consulta só, vários níveis de agrupamento.

| Forma | Grupos gerados | Uso |
|---|---|---|
| `GROUP BY ROLLUP(a, b)` | `(a, b)`, `(a)`, `()` | Subtotais hierárquicos: total por UF e ano, subtotal por UF, total geral |
| `GROUP BY CUBE(a, b)` | `(a, b)`, `(a)`, `(b)`, `()` | Todas as combinações: tabela cruzada com totais de linha e de coluna |
| `GROUP BY GROUPING SETS ((a), (b), ())` | Exatamente os listados | Quando só alguns níveis interessam |

Nas linhas de subtotal, as colunas "somadas" aparecem como **NULL**.

## GROUPING e GROUPING_ID

Um NULL na linha de resultado pode ser subtotal ou pode ser um NULL de verdade nos dados (por exemplo, pedidos sem vendedor). `GROUPING(coluna)` devolve 1 quando o NULL é de subtotal e 0 quando é dado:

```sql
SELECT CASE WHEN GROUPING(uf) = 1 THEN 'TOTAL' ELSE uf END AS uf, ...
  FROM ...
 GROUP BY ROLLUP(uf);
```

`GROUPING_ID(a, b)` junta os indicadores num número (bit a bit) e serve para filtrar ou ordenar os níveis: 0 = detalhe, 1 = subtotal de `a`, 3 = total geral.

## Armadilhas

- **Granularidade antes do GROUP BY.** Agrupar pedidos depois de um join com itens conta itens, não pedidos. `COUNT(*)` vira `COUNT(DISTINCT p.id_pedido)`, ou a agregação de itens vai para uma inline view.
- **Agrupar por coluna a mais** (por exemplo, `nome` e `id_cliente` quando o nome muda de grafia entre linhas) parte o grupo.
- **Ordem não é garantida.** `GROUP BY` não ordena. Se a ordem importa, `ORDER BY`.
- **NULL de subtotal confundido com NULL de dado.** Use `GROUPING()`.

## Documentação oficial

- [SQL Language Reference — SELECT (group_by_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
- [Data Warehousing Guide — SQL for Aggregation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-aggregation-data-warehouses.html)
