# Funções equivalentes: texto, data, NULL, conversão

As versões mínimas indicadas são as que costumam pegar quem migra: `STRING_AGG` no SQL Server só a partir do 2017, `GREATEST` só a partir do 2022, e assim por diante.

## NULL

| Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|
| `NVL(a, b)` | `COALESCE(a, b)` | `ISNULL(a, b)` ou `COALESCE` | `IFNULL(a, b)` ou `COALESCE` |
| `NVL2(a, se_nao_nulo, se_nulo)` | `CASE WHEN a IS NOT NULL THEN ... ELSE ... END` | idem `CASE` | idem `CASE` |
| `NULLIF(a, b)` | `NULLIF` | `NULLIF` | `NULLIF` |
| `DECODE(x, 1, 'a', 2, 'b', 'c')` | `CASE x WHEN 1 THEN 'a' ...` | `CASE` (ou `CHOOSE` para índices) | `CASE` |

`COALESCE` e `CASE` são padrão SQL e funcionam nos quatro: prefira em código que precisa ser portável. `ISNULL` do SQL Server devolve o tipo do primeiro argumento (pode truncar o segundo); `COALESCE` usa a regra de precedência de tipos.

## Texto

| Operação | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Concatenar | `a \|\| b` | `a \|\| b` | `a + b` ou `CONCAT(a, b)` | `CONCAT(a, b)` (`\|\|` é OR, salvo modo `PIPES_AS_CONCAT`) |
| Pedaço | `SUBSTR(s, ini, qtd)` | `SUBSTRING(s FROM ini FOR qtd)` ou `SUBSTR` | `SUBSTRING(s, ini, qtd)` (qtd obrigatória) | `SUBSTRING(s, ini, qtd)` ou `SUBSTR` |
| Posição | `INSTR(s, 'x')` | `POSITION('x' IN s)`, `STRPOS(s, 'x')` | `CHARINDEX('x', s)` (ordem invertida) | `INSTR(s, 'x')`, `LOCATE('x', s)` |
| Tamanho | `LENGTH(s)` | `LENGTH(s)`, `CHAR_LENGTH` | `LEN(s)` (**ignora espaços finais**), `DATALENGTH` em bytes | `CHAR_LENGTH(s)` (**`LENGTH` é em bytes**) |
| Preencher | `LPAD(s, 5, '0')` | `LPAD` | `RIGHT(REPLICATE('0', 5) + s, 5)` ou `FORMAT` | `LPAD` |
| Aparar | `TRIM`, `LTRIM`, `RTRIM` | `TRIM`, `LTRIM`, `RTRIM`, `BTRIM` | `TRIM` (2017+), `LTRIM`, `RTRIM` | `TRIM`, `LTRIM`, `RTRIM` |
| Substituir | `REPLACE`, `TRANSLATE` | `REPLACE`, `TRANSLATE` | `REPLACE`, `TRANSLATE` (2017+) | `REPLACE` |
| Maiúsculas | `UPPER`, `LOWER`, `INITCAP` | `UPPER`, `LOWER`, `INITCAP` | `UPPER`, `LOWER` | `UPPER`, `LOWER` |
| Agregar em lista | `LISTAGG(x, ', ') WITHIN GROUP (ORDER BY x)` | `STRING_AGG(x, ', ' ORDER BY x)` | `STRING_AGG(x, ', ') WITHIN GROUP (ORDER BY x)` (2017+) | `GROUP_CONCAT(x ORDER BY x SEPARATOR ', ')` (limite `group_concat_max_len`) |
| Expressão regular | `REGEXP_LIKE`, `REGEXP_SUBSTR`, `REGEXP_REPLACE` | `~`, `~*`, `regexp_match`, `regexp_replace` | `REGEXP_LIKE` e família no SQL Server 2025; antes, só `LIKE` com `[a-z]` ou CLR | `REGEXP_LIKE`, `REGEXP_SUBSTR`, `REGEXP_REPLACE` (8.0+) |

## Data

| Operação | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Agora | `SYSDATE`, `SYSTIMESTAMP` | `now()`, `CURRENT_TIMESTAMP` | `GETDATE()`, `SYSDATETIME()` | `NOW()`, `SYSDATE()` |
| Hoje, sem hora | `TRUNC(SYSDATE)` | `CURRENT_DATE` | `CAST(GETDATE() AS date)` | `CURDATE()` |
| Truncar a mês | `TRUNC(d, 'MM')` | `date_trunc('month', d)` | `DATETRUNC(month, d)` (2022+), antes `DATEFROMPARTS(YEAR(d), MONTH(d), 1)` | `DATE(DATE_FORMAT(d, '%Y-%m-01'))` |
| Somar dias | `d + 30` | `d + 30` (date) ou `d + INTERVAL '30 days'` | `DATEADD(day, 30, d)` | `DATE_ADD(d, INTERVAL 30 DAY)` |
| Somar meses | `ADD_MONTHS(d, 1)` | `d + INTERVAL '1 month'` | `DATEADD(month, 1, d)` | `DATE_ADD(d, INTERVAL 1 MONTH)` |
| Diferença em dias | `d2 - d1` (com fração, se houver hora) | `d2 - d1` (date: inteiro; timestamp: interval) | `DATEDIFF(day, d1, d2)` (conta fronteiras de dia) | `DATEDIFF(d2, d1)` (**ordem invertida** em relação ao SQL Server) |
| Diferença em meses | `MONTHS_BETWEEN(d2, d1)` | `age(d2, d1)` e `extract` | `DATEDIFF(month, d1, d2)` | `TIMESTAMPDIFF(MONTH, d1, d2)` |
| Último dia do mês | `LAST_DAY(d)` | `date_trunc('month', d) + INTERVAL '1 month - 1 day'` | `EOMONTH(d)` | `LAST_DAY(d)` |
| Parte da data | `EXTRACT(YEAR FROM d)`, `TO_CHAR(d, 'MM')` | `EXTRACT`, `date_part` | `YEAR(d)`, `DATEPART(month, d)` | `YEAR(d)`, `EXTRACT` |

## Conversão e formatação

| Operação | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Data em texto | `TO_CHAR(d, 'DD/MM/YYYY HH24:MI')` | `to_char(d, 'DD/MM/YYYY HH24:MI')` | `FORMAT(d, 'dd/MM/yyyy HH:mm')` ou `CONVERT(varchar(10), d, 103)` | `DATE_FORMAT(d, '%d/%m/%Y %H:%i')` |
| Texto em data | `TO_DATE('27/11/2026', 'DD/MM/YYYY')` | `to_date('27/11/2026', 'DD/MM/YYYY')` | `CONVERT(date, '27/11/2026', 103)` | `STR_TO_DATE('27/11/2026', '%d/%m/%Y')` |
| Texto em número | `TO_NUMBER('12,5', '99D9', 'NLS_NUMERIC_CHARACTERS='',.''')` | `CAST('12.5' AS numeric)`, `to_number` | `CAST`, `TRY_CAST` | `CAST('12.5' AS DECIMAL(10,2))` |
| Conversão que não falha | `TO_NUMBER(x DEFAULT NULL ON CONVERSION ERROR)` `[12.2+]`, `VALIDATE_CONVERSION` | (não há nativa: função com `EXCEPTION`) | `TRY_CAST`, `TRY_CONVERT` | `CAST` devolve 0 ou NULL com aviso, conforme o modo SQL |
| Maior e menor de uma lista | `GREATEST`, `LEAST` | `GREATEST`, `LEAST` (ignoram NULL) | `GREATEST`, `LEAST` (2022+) | `GREATEST`, `LEAST` |

`GREATEST` e `LEAST` no Oracle e no MySQL devolvem NULL se **algum** argumento for NULL; no PostgreSQL e no SQL Server, ignoram os NULL. Mesmo nome, resultado diferente.

As máscaras de data também mudam: no Oracle, `MM` é mês e `MI` é minuto; no `FORMAT` do SQL Server, `MM` é mês e `mm` é minuto; no MySQL, `%m` é mês e `%i` é minuto.

## Documentação

- [Oracle — Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Functions.html)
- [PostgreSQL — Functions and Operators](https://www.postgresql.org/docs/current/functions.html)
- [SQL Server — Functions](https://learn.microsoft.com/sql/t-sql/functions/functions)
- [MySQL — Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/functions.html)
