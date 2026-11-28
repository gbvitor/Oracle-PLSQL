# 14 — Outros SGBDs

Conceitos de banco de dados que valem para qualquer SGBD e a tradução da sintaxe Oracle para PostgreSQL, SQL Server e MySQL.

Os tópicos são explicações com exemplos em blocos de código para cada banco; rodar os exemplos exige o banco correspondente. O tópico 08 tem um script com o lado Oracle das diferenças, para comparar. Versões de referência: Oracle 19c (com as novidades do 23ai marcadas), PostgreSQL 13 em diante, SQL Server 2017 em diante (recursos do 2022 e do 2025 indicados), MySQL 8.0/8.4.

## Conceitos

| # | Tópico | Explicação |
|---|---|---|
| 01 | O que é um SGBD; relacional versus não relacional | [md](01-sgbd-relacional-e-nao-relacional.md) |
| 02 | Propriedades ACID e controle de concorrência (MVCC e locks) nos quatro bancos | [md](02-acid-e-concorrencia.md) |
| 03 | Normalização e desnormalização, com o schema de exemplo | [md](03-normalizacao.md) |
| 04 | OLTP versus OLAP; data warehouse, esquema estrela, SCD, ETL e ELT | [md](04-oltp-olap-e-data-warehouse.md) |

## Comparação de sintaxe e comportamento

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 05 | Tipos de dados equivalentes e as armadilhas de tradução | [md](05-tipos-de-dados.md) | |
| 06 | Funções equivalentes: NULL, texto, data, conversão | [md](06-funcoes-equivalentes.md) | |
| 07 | Top-N, paginação (OFFSET e por chave) e auto incremento | [md](07-top-n-paginacao-autoincremento.md) | |
| 08 | DUAL, concatenação, string vazia, divisão, maiúsculas, NULL na ordenação | [md](08-dual-concatenacao-string-vazia.md) | [sql (lado Oracle)](08-dual-concatenacao-string-vazia.sql) |
| 09 | Linguagem procedural: PL/SQL × PL/pgSQL × T-SQL × MySQL, com a mesma procedure nos quatro | [md](09-linguagem-procedural.md) | |
| 10 | Transações, autocommit, DDL transacional, erro no meio da transação | [md](10-transacoes-e-ddl.md) | |
| 11 | Dicionário de dados e visões de sessão em cada SGBD | [md](11-dicionario-de-dados.md) | |

Continua em [15 — Casos de uso](../15-casos-de-uso/README.md).
