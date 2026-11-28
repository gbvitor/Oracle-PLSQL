# Tabelas e colunas: USER_TABLES, USER_TAB_COLUMNS, comentários

## As visões

| Visão | Uma linha por | Colunas mais usadas |
|---|---|---|
| `USER_TABLES` | Tabela | `TABLE_NAME`, `NUM_ROWS`, `BLOCKS`, `LAST_ANALYZED`, `PARTITIONED`, `TEMPORARY`, `IOT_TYPE`, `TABLESPACE_NAME` |
| `USER_TAB_COLUMNS` | Coluna de tabela, view ou materialized view | `TABLE_NAME`, `COLUMN_ID`, `COLUMN_NAME`, `DATA_TYPE`, `DATA_LENGTH`, `DATA_PRECISION`, `DATA_SCALE`, `CHAR_LENGTH`, `CHAR_USED`, `NULLABLE`, `DATA_DEFAULT` |
| `USER_TAB_COLS` | O mesmo, **incluindo colunas ocultas e virtuais** (`HIDDEN_COLUMN`, `VIRTUAL_COLUMN`) | |
| `USER_TAB_COMMENTS` | Tabela ou view | `COMMENTS` |
| `USER_COL_COMMENTS` | Coluna | `COMMENTS` |

`USER_TAB_COLUMNS` também traz as colunas de **views**: para saber se o nome é de tabela, junte com `USER_TABLES` ou consulte `USER_OBJECTS.OBJECT_TYPE`.

## Lendo o tipo de uma coluna

| Tipo | Como montar o texto do tipo |
|---|---|
| `NUMBER` | `DATA_PRECISION` e `DATA_SCALE`; os dois NULL = `NUMBER` sem limite; precisão NULL e escala 0 = `INTEGER` |
| `VARCHAR2`, `CHAR` | `CHAR_LENGTH` e `CHAR_USED` (`B` = bytes, `C` = caracteres). `DATA_LENGTH` é sempre em bytes |
| `DATE`, `TIMESTAMP(n)` | O próprio `DATA_TYPE` já traz a precisão do TIMESTAMP |

`DATA_DEFAULT` é `LONG`: aparece na consulta, mas não pode ser filtrado (tópico 01).

## Estatísticas: NUM_ROWS

`NUM_ROWS`, `BLOCKS`, `AVG_ROW_LEN` e `LAST_ANALYZED` vêm da **última coleta de estatísticas** (`DBMS_STATS`, seção 11). O job automático do Oracle coleta numa janela noturna; tabela recém-criada e carregada pode estar com NULL. Para saber quantas linhas há **agora**, só `COUNT(*)`.

## Consultas que resolvem o dia a dia

- **"Que tabela tem a coluna X?"**: `USER_TAB_COLUMNS WHERE column_name = 'ID_CLIENTE'`. Num banco grande, é a forma mais rápida de achar onde um dado mora.
- **"Que colunas têm o mesmo nome em tabelas diferentes?"**: candidatas a chave de junção, mesmo sem FK declarada (comum em sistemas legados e ERPs que não declaram FKs).
- **"Que tabelas não têm comentário?"**: documentação faltando.
- **Lista de colunas para um SELECT ou INSERT**: `LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id)` gera o texto pronto, sem `SELECT *`.
- **"DESCRIBE" em forma de consulta**: o comando `DESC` do SQL*Plus é cômodo, mas não filtra, não ordena e não junta com nada.

## Documentação oficial

- [Database Reference — ALL_TABLES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_TABLES.html)
- [Database Reference — ALL_TAB_COLUMNS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_TAB_COLUMNS.html)
- [Database Reference — ALL_COL_COMMENTS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_COL_COMMENTS.html)
