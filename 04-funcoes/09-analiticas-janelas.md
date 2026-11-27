# Funções analíticas III: janelas, acumulados e médias móveis

## A cláusula de janela

Funções de agregação usadas como analíticas (`SUM`, `AVG`, `COUNT`, `MIN`, `MAX`) e `FIRST_VALUE`/`LAST_VALUE` calculam sobre uma **janela**: um subconjunto da partição definido em relação à linha atual.

```sql
SUM(valor) OVER (
    PARTITION BY ...
    ORDER BY data
    { ROWS | RANGE } BETWEEN inicio AND fim
)
```

| Limite | Significa |
|---|---|
| `UNBOUNDED PRECEDING` | Início da partição |
| `n PRECEDING` | n linhas (ou n unidades de valor, com `RANGE`) antes |
| `CURRENT ROW` | Linha atual |
| `n FOLLOWING` | n depois |
| `UNBOUNDED FOLLOWING` | Fim da partição |

## Janela padrão

| `OVER` | Janela usada |
|---|---|
| `OVER ()` | A partição inteira |
| `OVER (PARTITION BY x)` | A partição inteira |
| `OVER (ORDER BY y)` | **`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`**: acumulado |

Acrescentar `ORDER BY` muda o resultado de "total da partição" para "acumulado até a linha". É o mesmo motivo da armadilha do `LAST_VALUE` (tópico 08).

## ROWS ou RANGE

- **ROWS** conta **linhas físicas**: `ROWS 2 PRECEDING` = a linha atual e as duas anteriores.
- **RANGE** considera **valores** do `ORDER BY`: linhas com o mesmo valor (empates) entram juntas; `RANGE BETWEEN INTERVAL '30' DAY PRECEDING AND CURRENT ROW` pega todas as linhas dos últimos 30 dias, quantas forem.

A diferença aparece com empate. Com a janela padrão (`RANGE`), duas linhas com a mesma data recebem o **mesmo** acumulado, que já soma as duas. Com `ROWS`, cada uma recebe um acumulado diferente. Para acumulado "linha a linha", use `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` e um `ORDER BY` sem empate.

## Padrões

| Necessidade | Expressão |
|---|---|
| Total da partição em cada linha | `SUM(v) OVER (PARTITION BY g)` |
| Percentual do total | `v / SUM(v) OVER ()` ou `RATIO_TO_REPORT(v) OVER ()` |
| Acumulado | `SUM(v) OVER (ORDER BY d ROWS UNBOUNDED PRECEDING)` |
| Acumulado que recomeça a cada ano | `SUM(v) OVER (PARTITION BY ano ORDER BY d ROWS UNBOUNDED PRECEDING)` |
| Média móvel de 3 períodos | `AVG(v) OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` |
| Soma dos últimos 90 dias (por data) | `SUM(v) OVER (ORDER BY d RANGE BETWEEN 90 PRECEDING AND CURRENT ROW)` |
| Diferença para a média do grupo | `v - AVG(v) OVER (PARTITION BY g)` |

`ROWS UNBOUNDED PRECEDING` é abreviação de `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.

Com `RANGE` numérico sobre `DATE`, a unidade é dia (`90 PRECEDING` = 90 dias). Sobre `TIMESTAMP`, use `INTERVAL`.

## Armadilhas

- **Média móvel nas primeiras linhas** usa menos períodos (a primeira linha é a média de um valor só). Se isso distorce, descarte as primeiras linhas ou use `COUNT(*) OVER (mesma janela)` para saber quantos valores entraram.
- **Média móvel com meses faltando**: `ROWS 2 PRECEDING` pega as duas linhas anteriores, que podem não ser os dois meses anteriores. Complete o calendário antes (tópico 08).
- **`RANGE` com várias colunas no `ORDER BY`** só aceita `UNBOUNDED` e `CURRENT ROW` como limites.

## Documentação oficial

- [SQL Language Reference — Analytic Functions (windowing_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
