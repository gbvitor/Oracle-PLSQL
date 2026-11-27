# Funções de conversão e máscaras de formato

## Funções

| Função | Converte | Exemplo |
|---|---|---|
| `TO_CHAR(data, 'máscara')` | Data → texto | `TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI')` |
| `TO_CHAR(número, 'máscara')` | Número → texto | `TO_CHAR(1234.5, 'FM999G999D00')` |
| `TO_DATE(texto, 'máscara')` | Texto → `DATE` | `TO_DATE('25/11/2026', 'DD/MM/YYYY')` |
| `TO_TIMESTAMP(texto, 'máscara')` | Texto → `TIMESTAMP` | `TO_TIMESTAMP('2026-11-25 10:00:00.5', 'YYYY-MM-DD HH24:MI:SS.FF')` |
| `TO_NUMBER(texto, 'máscara')` | Texto → número | `TO_NUMBER('1.234,56', '9G999D99')` |
| `CAST(expr AS tipo)` | Qualquer conversão suportada, padrão SQL | `CAST('42' AS NUMBER)` |

O terceiro argumento opcional de `TO_CHAR`, `TO_DATE` e `TO_NUMBER` fixa parâmetros NLS só para aquela chamada, sem depender da sessão:

```sql
TO_CHAR(data, 'DD "de" fmMonth "de" YYYY', 'NLS_DATE_LANGUAGE = BRAZILIAN PORTUGUESE')
TO_NUMBER('1.234,56', '9G999D99', 'NLS_NUMERIC_CHARACTERS = '',.''')
```

## Máscaras de data

| Elemento | Significado | Exemplo (25/11/2026 14:05:09, quarta) |
|---|---|---|
| `YYYY` / `YY` | Ano com 4 / 2 dígitos | `2026` / `26` |
| `RR` | Ano de 2 dígitos com janela de século (00–49 = 20xx, 50–99 = 19xx) | |
| `MM` | Mês, 01–12 | `11` |
| `MON` / `MONTH` | Nome abreviado / completo do mês | `NOV` / `NOVEMBRO ` (completado com espaços) |
| `DD` | Dia do mês | `25` |
| `DDD` | Dia do ano | `329` |
| `DY` / `DAY` | Dia da semana abreviado / completo | `QUA` / `QUARTA-FEIRA` |
| `D` | Dia da semana em número (depende de `NLS_TERRITORY`) | |
| `IW` / `WW` | Semana ISO / semana contada a partir de 1º de janeiro | |
| `Q` | Trimestre | `4` |
| `HH24` / `HH` ou `HH12` | Hora 0–23 / 1–12 | `14` / `02` |
| `MI` / `SS` | Minuto / segundo | `05` / `09` |
| `FF[1-9]` | Fração de segundo (só `TIMESTAMP`) | |
| `AM` / `PM` | Indicador de período | |
| `"texto"` | Texto literal | `DD "de" MM` |

Modificadores:

- **`FM`** (fill mode) liga e desliga a remoção de espaços e zeros à esquerda: `TO_CHAR(d, 'FMDD/MM')` dá `5/3` em vez de `05/03`; `fmMonth` tira os espaços depois do nome do mês.
- **`FX`** (format exact) exige que o texto do `TO_DATE` bata exatamente com a máscara. Sem `FX`, o Oracle é tolerante com separadores e zeros à esquerda.

## Máscaras de número

| Elemento | Significado | Exemplo | Resultado |
|---|---|---|---|
| `9` | Dígito, sem zero à esquerda | `TO_CHAR(42, '9999')` | `'   42'` |
| `0` | Dígito, com zero à esquerda | `TO_CHAR(42, '0000')` | `' 0042'` |
| `D` | Separador decimal da sessão | `TO_CHAR(1.5, '9D99')` | `' 1,50'` |
| `G` | Separador de milhar da sessão | `TO_CHAR(1234, '9G999')` | `' 1.234'` |
| `.` e `,` | Separadores fixos, ignorando a sessão | `TO_CHAR(1234.5, '9,999.99')` | `' 1,234.50'` |
| `L` | Símbolo da moeda local (`NLS_CURRENCY`) | `TO_CHAR(10, 'FML99D99')` | `R$10,00` |
| `FM` | Remove espaços à esquerda | `TO_CHAR(42, 'FM9999')` | `'42'` |
| `S` / `MI` | Sinal no início / sinal negativo no fim | | |
| `EEEE` | Notação científica | | |
| `X` | Hexadecimal | `TO_CHAR(255, 'XX')` | `'FF'` |

O espaço à esquerda nos resultados sem `FM` é reservado para o sinal. Se o número não cabe na máscara, o resultado é uma sequência de `#`.

Os resultados com `D` e `G` acima supõem sessão com `NLS_NUMERIC_CHARACTERS = ',.'`.

## Conversão tolerante a erro `[12.2+]`

```sql
TO_NUMBER(texto DEFAULT NULL ON CONVERSION ERROR)
TO_DATE(texto DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY')
CAST(texto AS NUMBER DEFAULT 0 ON CONVERSION ERROR)
VALIDATE_CONVERSION(texto AS NUMBER)
VALIDATE_CONVERSION(texto AS DATE, 'DD/MM/YYYY')
```

`VALIDATE_CONVERSION` devolve 1 quando o valor converte e 0 quando não converte. Essas funções são indispensáveis para tratar dados importados de planilha ou de outro sistema: em vez de a consulta inteira falhar na primeira linha suja, as linhas inválidas viram NULL (ou um valor padrão) e podem ser listadas com `VALIDATE_CONVERSION = 0`.

## Armadilhas

- **`YYYY` e `RR` ao ler ano com 2 dígitos.** `TO_DATE('01/01/49', 'DD/MM/YY')` dá o ano 2049 se o ano atual for 20xx; com `RR`, também 2049; `'01/01/50'` com `YY` dá 2050, com `RR` dá 1950. Prefira sempre 4 dígitos.
- **`MM` versus `MI`.** `'DD/MM/YYYY HH24:MM'` usa o mês no lugar do minuto. Erro comum e silencioso.
- **`HH` sem `AM`/`PM`.** `TO_DATE('14:00', 'HH:MI')` dá erro (ORA-01849), porque `HH` vai de 1 a 12.
- **`MONTH` e `DAY` completam com espaços.** Use `FM`.
- **`TO_CHAR` sem máscara** usa o formato da sessão: o resultado muda de uma ferramenta para outra.

## Documentação oficial

- [SQL Language Reference — Format Models](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Format-Models.html)
- [SQL Language Reference — Conversion Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Single-Row-Functions.html)
