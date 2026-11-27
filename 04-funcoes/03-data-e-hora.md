# Funções de data e hora

A aritmética com datas e intervalos está na seção 03, tópico 04; a conversão entre data e texto, no tópico 04 desta seção. Aqui estão as funções.

## Data e hora atuais

| Função | Tipo | Referência |
|---|---|---|
| `SYSDATE` | `DATE` | Relógio do sistema operacional do servidor do banco |
| `SYSTIMESTAMP` | `TIMESTAMP WITH TIME ZONE` | Idem, com fração de segundo e fuso |
| `CURRENT_DATE` | `DATE` | Fuso horário da **sessão** |
| `CURRENT_TIMESTAMP` | `TIMESTAMP WITH TIME ZONE` | Fuso da sessão |
| `LOCALTIMESTAMP` | `TIMESTAMP` | Fuso da sessão, sem a informação de fuso |

Todas devolvem o mesmo valor em todas as linhas de um mesmo comando.

## Partes de uma data

| Função | Exemplo | Resultado |
|---|---|---|
| `EXTRACT(YEAR FROM d)` (também `MONTH`, `DAY`) | `EXTRACT(MONTH FROM DATE '2026-11-25')` | `11` |
| `EXTRACT(HOUR FROM ts)` (também `MINUTE`, `SECOND`, `TIMEZONE_HOUR`) | Só para `TIMESTAMP` | |
| `TO_CHAR(d, 'formato')` | `TO_CHAR(d, 'HH24')` | Qualquer parte, como texto (tópico 04) |

`EXTRACT(HOUR FROM coluna_date)` dá **ORA-30076**: para `DATE`, o `EXTRACT` só aceita ano, mês e dia. Use `TO_CHAR(d, 'HH24')` ou `EXTRACT(HOUR FROM CAST(d AS TIMESTAMP))`.

## Calendário

| Função | O que faz |
|---|---|
| `ADD_MONTHS(d, n)` | Soma meses, ajustando o fim de mês |
| `MONTHS_BETWEEN(d2, d1)` | Meses entre as datas, com fração (base de 31 dias para a parte fracionária) |
| `LAST_DAY(d)` | Último dia do mês |
| `NEXT_DAY(d, 'dia')` | Próxima ocorrência do dia da semana **depois** de `d`; o nome do dia depende do idioma da sessão |
| `TRUNC(d, 'formato')` | Início do período: `'DD'`, `'MM'`, `'Q'` (trimestre), `'YYYY'`, `'IW'` (semana ISO), `'HH24'`, `'MI'` |
| `ROUND(d, 'formato')` | Arredonda para o período mais próximo: `ROUND(d, 'MM')` vai para o mês seguinte a partir do dia 16 |

## Fuso horário

| Função | O que faz |
|---|---|
| `FROM_TZ(ts, 'fuso')` | Atribui um fuso a um `TIMESTAMP` sem fuso |
| `ts AT TIME ZONE 'fuso'` | Converte para outro fuso |
| `SYS_EXTRACT_UTC(tstz)` | Converte para UTC |
| `SESSIONTIMEZONE` / `DBTIMEZONE` | Fuso da sessão / do banco |
| `TZ_OFFSET('fuso')` | Diferença do fuso em relação ao UTC |

Use nomes de região (`'America/Sao_Paulo'`) e não deslocamentos fixos (`'-03:00'`): a região acompanha mudanças de horário de verão; o deslocamento não.

## Armadilhas

- **`NEXT_DAY` com nome em inglês** numa sessão em português (ou o contrário) dá ORA-01846. Sem depender de idioma: próxima segunda-feira = `TRUNC(d, 'IW') + 7`.
- **`TO_CHAR(d, 'D')`** (dia da semana em número) depende de `NLS_TERRITORY`: domingo é 1 no Brasil e nos EUA, segunda é 1 em boa parte da Europa. Para independência, `TO_CHAR(d, 'DY', 'NLS_DATE_LANGUAGE = ENGLISH')` ou `TRUNC(d) - TRUNC(d, 'IW') + 1` (1 = segunda).
- **`SYSDATE` num container em UTC** fica 3 horas adiantado em relação ao horário de Brasília. Confira `SESSIONTIMEZONE` e o fuso do servidor antes de comparar horários.
- **`CURRENT_DATE` em job agendado** usa o fuso da sessão do job, que pode não ser o mesmo da sua sessão interativa.

## Documentação oficial

- [SQL Language Reference — Datetime Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Single-Row-Functions.html)
