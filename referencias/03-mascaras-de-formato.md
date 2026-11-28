# Máscaras de formato: TO_CHAR, TO_DATE, TO_NUMBER

Explicação e armadilhas em detalhe: seção 04, tópicos 03 (data) e 04 (conversão), e seção 03, tópico 06 (conversão implícita).

## Regra de ouro

Nunca dependa do formato da sessão (`NLS_DATE_FORMAT`, `NLS_NUMERIC_CHARACTERS`): ele muda de máquina para máquina. Em código, sempre a máscara explícita, e para literal de data o formato ANSI:

```sql
DATE '2026-11-28'
TIMESTAMP '2026-11-28 14:30:00'
TO_DATE('28/11/2026 14:30', 'DD/MM/YYYY HH24:MI')
```

## Data e hora

| Elemento | Significado | Exemplo (28/11/2026 14:05:09, sábado) |
|---|---|---|
| `YYYY` | Ano com 4 dígitos | 2026 |
| `YY` | 2 últimos dígitos | 26 |
| `RR` | Ano de 2 dígitos com janela de século (entrada) | `'26'` → 2026, `'75'` → 1975 |
| `IYYY` | Ano ISO (da semana ISO) | 2026 |
| `Q` | Trimestre | 4 |
| `MM` | Mês, 01–12 | 11 |
| `MON` / `MONTH` | Nome abreviado / completo, no idioma de `NLS_DATE_LANGUAGE` | NOV / NOVEMBRO |
| `WW` | Semana do ano, contando a partir de 1º de janeiro | 48 |
| `IW` | Semana ISO (começa na segunda) | 48 |
| `W` | Semana do mês (1–5, a partir do dia 1) | 4 |
| `DDD` | Dia do ano | 332 |
| `DD` | Dia do mês | 28 |
| `D` | Dia da semana: **depende de `NLS_TERRITORY`** | 7 (Brasil, domingo = 1) |
| `DY` / `DAY` | Nome do dia abreviado / completo | SÁB / SÁBADO |
| `HH24` | Hora 00–23 | 14 |
| `HH` ou `HH12` | Hora 01–12 (use com `AM`/`PM`) | 02 |
| `AM` / `PM` | Indicador | PM |
| `MI` | Minuto | 05 |
| `SS` | Segundo | 09 |
| `SSSSS` | Segundos desde a meia-noite | 50709 |
| `FF` / `FF3` | Frações de segundo (TIMESTAMP) | 000 |
| `TZH:TZM` / `TZR` | Fuso: deslocamento / região (TIMESTAMP WITH TIME ZONE) | -03:00 / AMERICA/ARAGUAINA |
| `J` | Dia juliano | 2461373 |
| `CC` | Século | 21 |
| `"texto"` | Literal | `"dia" DD` → dia 28 |
| `- / , . ; :` | Pontuação, copiada como está | |

### Modificadores

| Modificador | Efeito |
|---|---|
| `FM` | Tira espaços e zeros à esquerda. `MONTH` é completado com espaços até o tamanho do nome mais longo; `FMMONTH` não. `FMDD` dá `5` em vez de `05`. Funciona como chave: o segundo `FM` desliga |
| `FX` | Na entrada (`TO_DATE`), exige que o texto siga a máscara exatamente (separadores e quantidade de dígitos) |
| Caixa do elemento | `MONTH` → NOVEMBRO, `Month` → Novembro, `month` → novembro (vale para `MON`, `DAY`, `DY`) |
| `TH`, `SP`, `SPTH` | Ordinal e por extenso, **em inglês** (`DDTH` → 28TH) |

### Exemplos

```sql
TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS')                      -- 28/11/2026 14:05:09
TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')                    -- 2026-11-28T14:05:09 (ISO 8601)
TO_CHAR(SYSDATE, 'FMDD "de" Month "de" YYYY', 'NLS_DATE_LANGUAGE=PORTUGUESE')  -- 28 de Novembro de 2026
TO_CHAR(SYSDATE, 'Dy', 'NLS_DATE_LANGUAGE=PORTUGUESE')        -- Sáb
TO_CHAR(SYSDATE, 'YYYY-"T"Q')                                  -- 2026-T4
TO_CHAR(SYSDATE, 'IYYY-"W"IW')                                 -- 2026-W48
TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3 TZH:TZM')                -- 14:05:09.123 -03:00
TO_DATE('2026-11-28 14:05', 'YYYY-MM-DD HH24:MI')
TO_TIMESTAMP('2026-11-28 14:05:09.5', 'YYYY-MM-DD HH24:MI:SS.FF')
TO_TIMESTAMP_TZ('2026-11-28 14:05 -03:00', 'YYYY-MM-DD HH24:MI TZH:TZM')
```

### Armadilhas

| Armadilha | Detalhe |
|---|---|
| `MM` × `MI` | `HH24:MM` mostra o **mês** no lugar do minuto, sem erro |
| `HH` sem `AM`/`PM` | 14h vira `02` |
| `D` para regra de negócio | Muda com `NLS_TERRITORY`. Use `d - TRUNC(d, 'IW')` (0 = segunda) — seção 15, caso 08 |
| `YYYY` × `IYYY` com `IW` | 31/12/2024 é semana ISO 1 de **2025**: `TO_CHAR(DATE '2024-12-31', 'YYYY-IW')` dá `2024-01`; `IYYY-IW` dá `2025-01` |
| `YY` na entrada | `TO_DATE('75', 'YY')` é 2075; `RR` dá 1975 |
| Campo omitido em `TO_DATE` | Dia ausente vira 1, mas **mês ausente vira o mês corrente**: `TO_DATE('2026', 'YYYY')` é o dia 1 do mês atual de 2026, não 01/01/2026 |
| Hora em `DATE` | `DATE` sempre tem hora. `WHERE data = DATE '2026-11-28'` só pega meia-noite; use intervalo `>= dia AND < dia + 1` |
| `TO_DATE` sobre coluna `DATE` | `TO_DATE(coluna_date, ...)` converte para texto pelo NLS e de volta: pode trocar dia e mês ou perder o século. Para tirar a hora, `TRUNC(coluna)` |
| Idioma de `MON` na entrada | `TO_DATE('28-NOV-2026', 'DD-MON-YYYY')` falha numa sessão em outro idioma se o nome não bater: fixe `NLS_DATE_LANGUAGE` na chamada |

Validar sem exceção `[12.2+]`:

```sql
TO_DATE(texto DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY')
VALIDATE_CONVERSION(texto AS DATE, 'DD/MM/YYYY')      -- 1 válido, 0 inválido
```

## Número

| Elemento | Significado | `TO_CHAR(-1234.5, ...)` |
|---|---|---|
| `9` | Dígito; posição vazia vira espaço | `'9999D99'` → `-1234,50` |
| `0` | Dígito; posição vazia vira zero | `'000000D00'` → `-001234,50` |
| `D` | Separador decimal da sessão (`NLS_NUMERIC_CHARACTERS`) | |
| `G` | Separador de milhar da sessão | `'9G999D00'` → `-1.234,50` |
| `.` `,` | Ponto e vírgula **literais**, fixos | `'9,999.00'` → `-1,234.50` |
| `L` | Símbolo de moeda local (`NLS_CURRENCY`) | `'L9G999D00'` → `-R$1.234,50` (conforme a sessão) |
| `$` | Cifrão fixo | |
| `MI` | Sinal de menos à direita | `'9999D99MI'` → `1234,50-` |
| `S` | Sinal `+` ou `-` explícito | `'S9999D99'` → `-1234,50` |
| `PR` | Negativo entre `< >` | `<1234,50>` |
| `B` | Zero vira espaços | |
| `EEEE` | Notação científica | `'9D99EEEE'` → `-1,23E+03` |
| `X` | Hexadecimal (só inteiros positivos) | `TO_CHAR(255, 'XX')` → `FF` |
| `RN` | Algarismos romanos (1 a 3999) | `TO_CHAR(2026, 'RN')` → `MMXXVI` |
| `TM9` / `TM` | Texto mínimo, sem máscara fixa | `-1234,5` |
| `FM` | Tira espaços à esquerda (o lugar do sinal) e zeros à direita depois do decimal, se a máscara for de `9` | `'FM9999D99'` → `-1234,5` |
| `V` | Multiplica por 10ⁿ | `TO_CHAR(12.3, '99V99')` → `1230` |

Os exemplos usam `NLS_NUMERIC_CHARACTERS = ',.'` (vírgula decimal). Para não depender da sessão, passe o terceiro parâmetro:

```sql
TO_CHAR(1234.5, 'FM9G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''')   -- 1.234,50 (Brasil)
TO_CHAR(1234.5, 'FM9G999G990D00', 'NLS_NUMERIC_CHARACTERS=''.,''')   -- 1,234.50 (EUA)
TO_CHAR(1234.5, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')              -- 1234.5 (para sistemas)
TO_NUMBER('1.234,50', '9G999D99', 'NLS_NUMERIC_CHARACTERS='',.''')   -- 1234.5
TO_NUMBER('1234.5', '9999D9', 'NLS_NUMERIC_CHARACTERS=''.,''')
```

### Armadilhas

| Armadilha | Detalhe |
|---|---|
| Número não cabe na máscara | Sai `#####`, sem erro: `TO_CHAR(12345, '999')` |
| Máscara de `9` sem `0` antes do decimal | `TO_CHAR(0.5, '9D99')` → ` ,50`; use `'0D99'` ou `'FM990D00'` |
| Espaço à esquerda | `TO_CHAR` reserva uma posição para o sinal: `TO_CHAR(5, '99')` → `' 5'`. `FM` ou `TRIM` |
| `TO_NUMBER` sem máscara | Usa o separador da sessão: `TO_NUMBER('1.5')` falha (ORA-01722) numa sessão com vírgula decimal |
| Zero à esquerda em código | `TO_NUMBER('00123')` perde o zero; código que tem zero à esquerda é texto |
| `TO_CHAR(n)` em concatenação implícita | Segue a sessão; valor gravado em texto (log, CSV, auditoria) deve usar `TM9` com o NLS fixo — seção 16, projeto 04 |

Validar sem exceção `[12.2+]`: `TO_NUMBER(texto DEFAULT NULL ON CONVERSION ERROR)` e `VALIDATE_CONVERSION(texto AS NUMBER)`.

## Intervalos

```sql
NUMTODSINTERVAL(90, 'MINUTE')          -- +00 01:30:00
NUMTOYMINTERVAL(18, 'MONTH')           -- +01-06
TO_DSINTERVAL('2 10:30:00')            -- 2 dias, 10h30
INTERVAL '400' DAY(3)                  -- precisão padrão é 2 dígitos: '400' DAY sozinho dá ORA-01873
EXTRACT(HOUR FROM intervalo)
```

## Documentação oficial

- [SQL Language Reference — Format Models](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Format-Models.html)
