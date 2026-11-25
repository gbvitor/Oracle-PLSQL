# Expressões com datas e intervalos

## Aritmética com DATE

| Expressão | Resultado | Tipo |
|---|---|---|
| `data + 1` | Um dia depois | `DATE` |
| `data + 1/24` | Uma hora depois | `DATE` |
| `data + 30/1440` | 30 minutos depois | `DATE` |
| `data - 7` | Uma semana antes | `DATE` |
| `data2 - data1` | Diferença em **dias**, com fração | `NUMBER` |
| `data1 + data2` | Erro ORA-00975: datas não se somam | |

Para horas entre duas datas: `(data2 - data1) * 24`. Para minutos: `* 1440`.

## Meses e anos

Meses têm tamanhos diferentes, então "um mês depois" não é um número fixo de dias.

| Função | Comportamento |
|---|---|
| `ADD_MONTHS(data, n)` | Soma n meses. Se a data é o **último dia** do mês, o resultado também é o último dia: `ADD_MONTHS(DATE '2026-01-31', 1)` = 28/02/2026; `ADD_MONTHS(DATE '2026-02-28', 1)` = 31/03/2026 |
| `MONTHS_BETWEEN(d2, d1)` | Meses entre as datas, com fração. Inteiro quando os dias coincidem ou ambos são fim de mês |
| `LAST_DAY(data)` | Último dia do mês |
| `TRUNC(data, 'MM')` | Primeiro dia do mês, 00:00 |
| `TRUNC(data, 'YYYY')` | 1º de janeiro |
| `TRUNC(data)` | Mesmo dia, 00:00 |

Idade ou tempo de casa em anos completos: `TRUNC(MONTHS_BETWEEN(data_ref, data_inicio) / 12)`.

## Intervalos

| Literal | Tipo |
|---|---|
| `INTERVAL '3' DAY` | `INTERVAL DAY TO SECOND` |
| `INTERVAL '2:30' HOUR TO MINUTE` | `INTERVAL DAY TO SECOND` |
| `INTERVAL '1' MONTH`, `INTERVAL '1-6' YEAR TO MONTH` | `INTERVAL YEAR TO MONTH` |

Conversões a partir de número: `NUMTODSINTERVAL(90, 'MINUTE')`, `NUMTOYMINTERVAL(18, 'MONTH')`.

`TIMESTAMP - TIMESTAMP` devolve `INTERVAL DAY TO SECOND`; para extrair partes, `EXTRACT(DAY FROM intervalo)`, `EXTRACT(HOUR FROM intervalo)`.

## A armadilha de INTERVAL MONTH

`DATE '2026-01-31' + INTERVAL '1' MONTH` **não** dá 28/02: dá **ORA-01839** (data inválida para o mês especificado), porque o intervalo soma mês sem ajustar o dia, e 31/02 não existe. Para somar meses a datas que podem cair no fim do mês, use `ADD_MONTHS`.

## Referência de "hoje"

| Expressão | O que é |
|---|---|
| `SYSDATE` | Data e hora do servidor |
| `TRUNC(SYSDATE)` | Hoje, 00:00 |
| `TRUNC(SYSDATE, 'MM')` | Primeiro dia do mês corrente |
| `ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1)` | Primeiro dia do mês anterior |
| `TRUNC(SYSDATE, 'IW')` | Segunda-feira da semana corrente (semana ISO) |

Relatórios "do mês anterior" ficam assim, em intervalo semiaberto:

```sql
WHERE data_pedido >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1)
  AND data_pedido <  TRUNC(SYSDATE, 'MM')
```

## Armadilhas

- **Somar 30 para "um mês".** Erra em 5 dos 12 meses.
- **`INTERVAL '1' MONTH` em fim de mês** (ORA-01839).
- **`TRUNC(data, 'W')`** trunca para o dia da semana do dia 1º do mês, não para domingo nem segunda. Para semana, use `'IW'` (ISO, segunda) ou `'D'` (depende de `NLS_TERRITORY`).
- **Comparar `DATE` com `TIMESTAMP`** converte a `DATE` para `TIMESTAMP` (seguro), mas comparar com texto converte pelo `NLS_DATE_FORMAT` (tópico 06).

## Documentação oficial

- [SQL Language Reference — Datetime/Interval Arithmetic](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Datetime-and-Interval-Arithmetic.html)
