# Tipos de dados equivalentes

## Tabela de equivalência

| Uso | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Inteiro | `NUMBER(10)`, `INTEGER` (= `NUMBER(38)`) | `integer`, `bigint`, `smallint` | `int`, `bigint`, `smallint`, `tinyint` | `INT`, `BIGINT`, `SMALLINT`, `TINYINT` |
| Decimal exato | `NUMBER(p,s)` | `numeric(p,s)` | `decimal(p,s)`, `numeric(p,s)` | `DECIMAL(p,s)` |
| Ponto flutuante | `BINARY_DOUBLE`, `BINARY_FLOAT` | `double precision`, `real` | `float`, `real` | `DOUBLE`, `FLOAT` |
| Dinheiro | `NUMBER(15,2)` | `numeric(15,2)` (evite `money`) | `decimal(15,2)` (evite `money`) | `DECIMAL(15,2)` |
| Texto variável | `VARCHAR2(n [BYTE\|CHAR])` | `varchar(n)`, `text` | `varchar(n)`, `nvarchar(n)` | `VARCHAR(n)` |
| Texto fixo | `CHAR(n)` | `char(n)` | `char(n)`, `nchar(n)` | `CHAR(n)` |
| Texto longo | `CLOB` | `text` | `varchar(max)`, `nvarchar(max)` | `TEXT`, `MEDIUMTEXT`, `LONGTEXT` |
| Data sem hora | (não há: `DATE` tem hora) | `date` | `date` | `DATE` |
| Data e hora | `DATE` (até segundos), `TIMESTAMP(n)` | `timestamp` | `datetime2(n)` (`datetime` é legado) | `DATETIME(n)` |
| Data e hora com fuso | `TIMESTAMP WITH TIME ZONE` | `timestamptz` | `datetimeoffset` | (não guarda o fuso; `TIMESTAMP` converte para UTC) |
| Intervalo | `INTERVAL DAY TO SECOND`, `INTERVAL YEAR TO MONTH` | `interval` | (não há) | (não há) |
| Booleano | `BOOLEAN` `[23ai+]`; antes, `CHAR(1)` ou `NUMBER(1)` com CHECK | `boolean` | `bit` | `BOOLEAN` (sinônimo de `TINYINT(1)`) |
| Binário | `RAW(n)`, `BLOB` | `bytea` | `varbinary(n)`, `varbinary(max)` | `VARBINARY(n)`, `BLOB`, `LONGBLOB` |
| UUID | `RAW(16)` com `SYS_GUID()` | `uuid` | `uniqueidentifier` | `BINARY(16)` ou `CHAR(36)` |
| JSON | `JSON` `[21c+]`; antes, `CLOB`/`VARCHAR2` com `IS JSON` | `jsonb` (binário, indexável), `json` | `json` (SQL Server 2025 e Azure SQL); antes, `nvarchar(max)` com `ISJSON` | `JSON` |

## As armadilhas mais comuns na tradução

**DATE do Oracle tem hora.** Migrar `DATE` do Oracle para `date` de outro banco **perde a hora**. O equivalente é `timestamp` / `datetime2` / `DATETIME`. No sentido inverso, uma coluna `date` de outro banco vira `DATE` no Oracle com hora 00:00:00, e filtros por igualdade passam a depender de `TRUNC` (seção 11, tópico 06).

**String vazia.** No Oracle, `''` é NULL (tópico 08). Uma coluna `NOT NULL` que recebe `''` de outro banco falha na migração.

**Tamanho de texto em bytes ou caracteres.** `VARCHAR2(10)` no Oracle é, por padrão, 10 **bytes** (seção 13, tópico 11). `varchar(10)` no PostgreSQL e no MySQL (com `utf8mb4`) é 10 **caracteres**. No SQL Server, `varchar(10)` são 10 bytes num collation não Unicode; para Unicode, `nvarchar` (ou collation UTF-8, desde o 2019).

**NUMBER sem precisão.** `NUMBER` puro no Oracle aceita qualquer número, inteiro ou decimal. Traduzido para `integer`, perde as casas decimais; para `numeric` sem precisão no PostgreSQL, mantém. Antes de migrar, confira os dados reais (`MAX(col - TRUNC(col))`).

**Inteiro e divisão.** `7 / 2` dá `3.5` no Oracle e no MySQL, mas `3` no PostgreSQL e no SQL Server quando os dois lados são inteiros (tópico 08).

**`TIMESTAMP` do MySQL** guarda em UTC e converte pelo fuso da sessão na leitura, com faixa limitada (até 2038); `DATETIME` guarda o valor como foi gravado. Não são intercambiáveis.

**Limites de `VARCHAR`.** Oracle: 4000 bytes em SQL (32767 com `MAX_STRING_SIZE = EXTENDED`), acima disso `CLOB`. SQL Server: 8000 bytes, acima disso `(max)`. PostgreSQL `text` e `varchar` sem limite prático.

## Documentação

- [Oracle — Data Types](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Data-Types.html)
- [PostgreSQL — Data Types](https://www.postgresql.org/docs/current/datatype.html)
- [SQL Server — Data types](https://learn.microsoft.com/sql/t-sql/data-types/data-types-transact-sql)
- [MySQL — Data Types](https://dev.mysql.com/doc/refman/8.4/en/data-types.html)
