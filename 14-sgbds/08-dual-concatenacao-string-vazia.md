# DUAL, concatenação, string vazia versus NULL e outras diferenças de comportamento

As diferenças deste tópico não geram erro: a consulta roda nos quatro bancos e dá **resultados diferentes**. São as que mais causam bug em migração.

## String vazia

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| `'' IS NULL` | **Verdadeiro** | Falso | Falso | Falso |
| `INSERT` de `''` em coluna `NOT NULL` | ORA-01400 | Aceito | Aceito | Aceito |
| `LENGTH('')` | NULL | 0 | `LEN('')` = 0 | 0 |

No Oracle, `''` **é** NULL (seção 01, tópico 04). Código que distingue "não informado" (NULL) de "informado vazio" (`''`) não funciona no Oracle; e dados vindos de outro banco com `''` viram NULL na carga.

## Concatenação com NULL

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| `'a' \|\| NULL` / `'a' + NULL` | `'a'` | **NULL** | **NULL** (padrão `CONCAT_NULL_YIELDS_NULL ON`) | `\|\|` é OR |
| `CONCAT('a', NULL)` | `'a'` | `'a'` | `'a'` | **NULL** |
| Ignorando NULL com separador | — | `CONCAT_WS(', ', a, b)` | `CONCAT_WS` (2017+) | `CONCAT_WS` |

No Oracle, NULL na concatenação some. Nos outros, contamina o resultado, a menos que se use `CONCAT` (PostgreSQL e SQL Server) ou `CONCAT_WS`, ou se envolva cada parte em `COALESCE(x, '')`.

## DUAL e SELECT sem FROM

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| `SELECT 1 + 1` | Só no `[23ai+]`; antes, `FROM dual` obrigatório | Sim | Sim | Sim |
| `SELECT 1 FROM dual` | Sim | Não | Não | Sim |

## Divisão de inteiros

| `SELECT 7 / 2` | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Resultado | 3.5 | **3** | **3** | 3.5000 |

No PostgreSQL e no SQL Server, inteiro dividido por inteiro é inteiro (trunca). `7 / 2.0` ou `CAST(7 AS numeric) / 2` dá 3.5. Cálculos de percentual (`qtd_vendida / qtd_total * 100`) dão 0 sem que nada avise. PostgreSQL e SQL Server também dão erro em divisão por zero, como o Oracle; o MySQL devolve NULL, com aviso.

## Maiúsculas e minúsculas

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Nome sem aspas (`clientes`) é guardado como | `CLIENTES` | `clientes` | Como foi escrito | Como foi escrito |
| Comparação de nomes de objeto | Exata depois da conversão | Exata depois da conversão | Depende do collation (normalmente sem distinção) | Tabelas: depende do sistema operacional (`lower_case_table_names`) |
| `'abc' = 'ABC'` em dados | **Falso** | **Falso** | **Verdadeiro** no collation padrão (`..._CI_AS`) | **Verdadeiro** no collation padrão (`utf8mb4_0900_ai_ci`) |
| Busca sem distinguir maiúsculas | `UPPER(x) = UPPER(y)`, `NLS_COMP` | `ILIKE`, extensão `citext` | Padrão | Padrão |

Consequência: uma chave única em `email` aceita `Ana@x.com` e `ana@x.com` como diferentes no Oracle e no PostgreSQL, e recusa o segundo no SQL Server e no MySQL. Acentos seguem a mesma lógica nos collations `_AI` / `_ai`.

## Outras

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Tipo de `TRUE`/`FALSE` em `WHERE` | `BOOLEAN` só no `[23ai+]`; antes, não existe em SQL | `boolean` | Não existe em SQL (`bit` não é condição) | `TRUE` = 1 |
| Aspas para identificador | `"Nome"` | `"Nome"` | `[Nome]` ou `"Nome"` | `` `Nome` `` |
| Comparação de texto com espaços no fim | `CHAR` completa com espaços; `VARCHAR2` compara exato | Exato em `varchar` | Ignora espaços finais (`'a' = 'a '` verdadeiro) | Ignora espaços finais em collations `PAD SPACE` |
| `NULL` em `ORDER BY ... ASC` | Por último | Por último | **Primeiro** | **Primeiro** |
| `NULLS FIRST` / `NULLS LAST` | Sim | Sim | Não (usar `CASE` no `ORDER BY`) | Não |
| Comparação que trata NULL como valor | `DECODE(a, b, 1, 0) = 1` | `IS [NOT] DISTINCT FROM` | `IS [NOT] DISTINCT FROM` (2022+) | `<=>` |

## Documentação

- [Oracle — Nulls](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Nulls.html)
- [PostgreSQL — String Functions and Operators](https://www.postgresql.org/docs/current/functions-string.html)
- [SQL Server — SET CONCAT_NULL_YIELDS_NULL](https://learn.microsoft.com/sql/t-sql/statements/set-concat-null-yields-null-transact-sql)
- [MySQL — Working with NULL Values](https://dev.mysql.com/doc/refman/8.4/en/working-with-null.html)
