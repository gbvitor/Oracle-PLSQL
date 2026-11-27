# Funções analíticas II: LAG, LEAD, FIRST_VALUE, LAST_VALUE, NTH_VALUE, KEEP

## Acesso a outras linhas

| Função | Devolve |
|---|---|
| `LAG(expr [, n [, padrao]])` | Valor de `n` linhas **antes** (padrão 1); `padrao` se não existir |
| `LEAD(expr [, n [, padrao]])` | Valor de `n` linhas **depois** |
| `FIRST_VALUE(expr)` | Primeiro valor da janela |
| `LAST_VALUE(expr)` | Último valor da janela |
| `NTH_VALUE(expr, n)` | O n-ésimo valor da janela |

Todas exigem `ORDER BY` no `OVER` para fazer sentido, e aceitam `IGNORE NULLS` para pular valores nulos (por exemplo, "último preço informado").

```sql
LAG(valor) OVER (PARTITION BY id_cliente ORDER BY data_pedido)
```

Usos: variação em relação ao período anterior, tempo entre eventos, detectar mudança de status, comparar com o próximo registro.

## LAG pega a linha anterior, não o período anterior

`LAG` olha a **linha** anterior na ordem. Se um mês não teve venda, não há linha para ele, e o "mês anterior" de junho passa a ser abril. Para comparar com o mês calendário anterior, gere antes a lista completa de meses (com `CONNECT BY` ou `WITH` recursivo) e faça outer join com os dados.

## A armadilha do LAST_VALUE

Com `ORDER BY` no `OVER` e sem janela explícita, a janela padrão é **do início da partição até a linha atual** (`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`). Por isso `LAST_VALUE(x) OVER (ORDER BY data)` devolve o valor da **própria linha**, não o último da partição.

Para o último de verdade:

```sql
LAST_VALUE(x) OVER (PARTITION BY ... ORDER BY data
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
```

ou, mais simples, `FIRST_VALUE(x) OVER (PARTITION BY ... ORDER BY data DESC)`.

## KEEP (DENSE_RANK FIRST | LAST)

Funciona como agregação (com `GROUP BY`) ou como analítica (com `OVER (PARTITION BY ...)`):

```sql
MAX(id_vendedor) KEEP (DENSE_RANK LAST ORDER BY data_pedido)
```

Considera só as linhas com o último valor de `data_pedido` do grupo e aplica `MAX` sobre elas. Responde "valor de B na linha onde A é máximo" sem subquery nem join, e costuma ser a forma mais eficiente para isso.

O `MAX` de fora ignora NULL como qualquer agregação: se a linha mais recente tem a coluna nula, o resultado é nulo (não o valor de uma linha anterior).

## Documentação oficial

- [SQL Language Reference — LAG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LAG.html)
- [SQL Language Reference — FIRST](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/FIRST.html)
