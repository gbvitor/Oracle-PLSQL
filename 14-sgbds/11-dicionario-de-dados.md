# Dicionário de dados: o equivalente ao ALL_TAB_COLUMNS em cada SGBD

O padrão SQL define o `INFORMATION_SCHEMA`, um conjunto de visões com a mesma estrutura em todos os bancos que o implementam. PostgreSQL, SQL Server e MySQL implementam; **o Oracle não**: usa as próprias visões `USER_`/`ALL_`/`DBA_` (seção 10). Cada banco também tem um catálogo próprio, mais completo que o `INFORMATION_SCHEMA`.

## Colunas de uma tabela

```sql
-- Oracle
SELECT column_name, data_type, data_length, data_precision, data_scale, nullable
  FROM all_tab_columns
 WHERE owner = 'VENDAS' AND table_name = 'PEDIDOS'
 ORDER BY column_id;

-- PostgreSQL, SQL Server, MySQL (INFORMATION_SCHEMA)
SELECT column_name, data_type, character_maximum_length, numeric_precision, numeric_scale, is_nullable
  FROM information_schema.columns
 WHERE table_schema = 'vendas' AND table_name = 'pedidos'
 ORDER BY ordinal_position;
```

Nomes: no Oracle, em maiúsculas (`'PEDIDOS'`); no PostgreSQL, em minúsculas (`'pedidos'`), porque é assim que nomes sem aspas são guardados; no SQL Server e no MySQL, como foram criados. No MySQL, `table_schema` é o nome do **banco** (database), que lá faz o papel de schema.

## Quadro de equivalências

| Informação | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Tabelas | `ALL_TABLES` | `information_schema.tables`, `pg_class` | `sys.tables`, `INFORMATION_SCHEMA.TABLES` | `information_schema.TABLES` |
| Colunas | `ALL_TAB_COLUMNS` | `information_schema.columns`, `pg_attribute` | `sys.columns`, `INFORMATION_SCHEMA.COLUMNS` | `information_schema.COLUMNS` |
| Constraints | `ALL_CONSTRAINTS`, `ALL_CONS_COLUMNS` | `information_schema.table_constraints`, `key_column_usage`, `pg_constraint` | `sys.key_constraints`, `sys.foreign_keys`, `sys.foreign_key_columns` | `information_schema.TABLE_CONSTRAINTS`, `KEY_COLUMN_USAGE`, `REFERENTIAL_CONSTRAINTS` |
| Índices | `ALL_INDEXES`, `ALL_IND_COLUMNS` | `pg_indexes`, `pg_index` | `sys.indexes`, `sys.index_columns` | `information_schema.STATISTICS` |
| Código | `ALL_SOURCE`, `DBMS_METADATA` | `pg_proc` (`prosrc`), `pg_get_functiondef(oid)` | `sys.sql_modules`, `OBJECT_DEFINITION(id)` | `information_schema.ROUTINES` |
| Views | `ALL_VIEWS` | `information_schema.views`, `pg_get_viewdef` | `sys.views` + `sys.sql_modules` | `information_schema.VIEWS` |
| Comentários | `ALL_TAB_COMMENTS`, `ALL_COL_COMMENTS` | `obj_description`, `col_description` | Extended properties (`sys.extended_properties`) | Coluna `TABLE_COMMENT` / `COLUMN_COMMENT` |
| Dependências | `ALL_DEPENDENCIES` | `pg_depend` | `sys.sql_expression_dependencies` | Limitado |
| DDL de um objeto | `DBMS_METADATA.GET_DDL` | `pg_dump --schema-only -t tabela` (fora do banco) | Scripting do SSMS, ou montar por `sys.*` | `SHOW CREATE TABLE` |
| Atalho no cliente | `DESC tabela` | `\d tabela` (psql) | `sp_help 'tabela'` | `DESCRIBE tabela` |

## Sessões, SQL e travas

| Informação | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Sessões | `V$SESSION` | `pg_stat_activity` | `sys.dm_exec_sessions`, `sys.dm_exec_requests` | `SHOW PROCESSLIST`, `performance_schema.threads` |
| SQL em execução | `V$SESSION.SQL_ID` + `V$SQL` | `pg_stat_activity.query` | `sys.dm_exec_requests` + `sys.dm_exec_sql_text` | `information_schema.PROCESSLIST.INFO` |
| Estatísticas de SQL | `V$SQL` | `pg_stat_statements` (extensão) | `sys.dm_exec_query_stats`, Query Store | `performance_schema.events_statements_summary_by_digest` |
| Travas e bloqueios | `V$LOCK`, `V$SESSION.BLOCKING_SESSION` | `pg_locks`, `pg_blocking_pids(pid)` | `sys.dm_tran_locks`, `blocking_session_id` em `dm_exec_requests` | `performance_schema.data_locks`, `sys.innodb_lock_waits` |
| Encerrar sessão | `ALTER SYSTEM KILL SESSION` | `pg_terminate_backend(pid)`; `pg_cancel_backend` cancela só o comando | `KILL spid` | `KILL id`; `KILL QUERY id` |
| Plano de execução | `DBMS_XPLAN` | `EXPLAIN (ANALYZE, BUFFERS)` | Plano gráfico, `SET STATISTICS XML ON`, Query Store | `EXPLAIN ANALYZE` (8.0.18+) |

O roteiro de descoberta de um schema da seção 10 (tópico 10) funciona em qualquer um dos quatro com as visões acima: tabelas e volume, chaves, mapa de FKs, índices, código e comentários.

## Documentação

- [Oracle — Static Data Dictionary Views](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/about-static-data-dictionary-views.html)
- [PostgreSQL — The Information Schema](https://www.postgresql.org/docs/current/information-schema.html)
- [PostgreSQL — System Catalogs](https://www.postgresql.org/docs/current/catalogs.html)
- [SQL Server — System catalog views](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/catalog-views-transact-sql)
- [MySQL — INFORMATION_SCHEMA Tables](https://dev.mysql.com/doc/refman/8.4/en/information-schema.html)
