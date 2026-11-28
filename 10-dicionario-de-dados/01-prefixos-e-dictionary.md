# Prefixos USER_, ALL_, DBA_ e CDB_; DICTIONARY

O **dicionário de dados** é o conjunto de tabelas internas (do usuário SYS) onde o Oracle guarda a descrição de tudo o que existe no banco: tabelas, colunas, constraints, índices, código, usuários, privilégios. Ninguém consulta as tabelas internas diretamente; o acesso é pelas **visões do dicionário**, que vêm em famílias com o mesmo nome e prefixos diferentes.

## Os prefixos

| Prefixo | Mostra | Coluna `OWNER` | Quem pode consultar |
|---|---|---|---|
| `USER_` | Objetos do **schema atual** | Não tem (é sempre você) | Todos |
| `ALL_` | Objetos que você **pode acessar** (seus e os que recebeu grant) | Tem | Todos |
| `DBA_` | **Todos** os objetos do banco (do container atual) | Tem | Quem tem `SELECT_CATALOG_ROLE`, `SELECT ANY DICTIONARY` ou é DBA |
| `CDB_` `[12c+]` | Todos os objetos de **todos os PDBs**, com a coluna `CON_ID` | Tem | Usuário comum conectado ao root do CDB |

Os nomes depois do prefixo se repetem: `USER_TABLES`, `ALL_TABLES`, `DBA_TABLES`, `CDB_TABLES`. Uma consulta escrita para `USER_` vira `ALL_` acrescentando `owner` no `WHERE` e no JOIN.

Regra prática:

- Explorando o próprio schema: `USER_`.
- Explorando o schema de outro usuário ou de uma aplicação: `ALL_ ... WHERE owner = 'NOME'` (só aparece o que você tem permissão de ver).
- Inventário do banco inteiro: `DBA_`.

## Visões dinâmicas (V$)

Além das visões estáticas acima, há as visões de desempenho dinâmico (`V$SESSION`, `V$SQL`, `V$LOCK`), que mostram o estado da **instância em memória**: sessões conectadas, SQL em cache, travas. O tópico 09 trata delas. Em RAC, `GV$` traz o mesmo de todas as instâncias.

## DICTIONARY: o índice do dicionário

Ninguém decora todas as visões. `DICTIONARY` (sinônimo `DICT`) lista todas, com um comentário; `DICT_COLUMNS` lista as colunas de cada uma.

```sql
SELECT table_name, comments FROM dictionary WHERE table_name LIKE 'USER%CONS%';
SELECT column_name, comments FROM dict_columns WHERE table_name = 'USER_TAB_COLUMNS';
```

## Detalhes que confundem

- **Nomes em maiúsculas.** O dicionário guarda identificadores sem aspas em maiúsculas: `WHERE table_name = 'CLIENTES'`, não `'clientes'`. Objeto criado com aspas e minúsculas (`"Clientes"`) fica gravado exatamente assim.
- **Colunas LONG.** Algumas colunas antigas são do tipo `LONG` (`USER_TAB_COLUMNS.DATA_DEFAULT`, `USER_CONSTRAINTS.SEARCH_CONDITION`, `USER_VIEWS.TEXT`, `USER_TRIGGERS.TRIGGER_BODY`). LONG não aceita `LIKE`, `SUBSTR` nem `UPPER`. Para filtrar pelo conteúdo, use as colunas `..._VC` quando a versão tiver, um bloco PL/SQL (onde LONG vira `VARCHAR2` de até 32760 bytes) ou `DBMS_METADATA.GET_DDL`.
- **Estatísticas não são contagem.** `USER_TABLES.NUM_ROWS` é o número de linhas **da última coleta de estatísticas**, não o atual. Pode estar NULL (nunca coletado) ou desatualizado.
- **Dicionário dentro de PL/SQL.** Numa procedure armazenada (`AUTHID DEFINER`), roles não valem (seção 09, tópico 14). `USER_` e `ALL_` funcionam sempre; `DBA_` e `V$` exigem privilégio concedido diretamente ao dono.

## Documentação oficial

- [Database Reference — Static Data Dictionary Views](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/about-static-data-dictionary-views.html)
- [Database Reference — DICTIONARY](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/DICTIONARY.html)
- [Database Concepts — Data Dictionary and Dynamic Performance Views](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-dictionary-and-dynamic-performance-views.html)
