# SQLcl: SQLFORMAT, DDL, INFO, HISTORY, ALIAS, LOAD, UNLOAD, Liquibase

SQLcl é o cliente de linha de comando moderno da Oracle: gratuito, escrito em Java (basta descompactar e ter Java instalado), sem precisar do Instant Client. Aceita os comandos e scripts do SQL*Plus e acrescenta recursos de produtividade. A numeração das versões segue o ano (24.x, 25.x).

```text
sql estudo@//localhost:1521/FREEPDB1
```

## O que o SQLcl tem a mais

| Recurso | Comando |
|---|---|
| Edição de linha, histórico com setas, **autocompletar** com Tab (tabelas, colunas, comandos) | Interativo |
| Formatos de saída | `SET SQLFORMAT csv \| json \| json-formatted \| insert \| loader \| html \| xml \| delimited \| fixed \| ansiconsole \| default` |
| DDL de um objeto | `DDL clientes` (com `DDL clientes arquivo.sql` grava em arquivo) |
| Ficha de um objeto | `INFO clientes` (colunas, chaves, índices, comentários); `INFO+ clientes` com estatísticas |
| Histórico de comandos | `HISTORY`, `HISTORY USAGE` (mais usados), `HISTORY TIME` (com duração), `HISTORY n` (executar o n-ésimo) |
| Apelidos | `ALIAS nome = consulta;`, `ALIAS LIST`, `ALIAS DROP nome` |
| Carga de CSV numa tabela | `LOAD tabela arquivo.csv` (com `NEW` cria a tabela pelo cabeçalho) |
| Descarga de tabela | `UNLOAD tabela` (gera arquivo no formato do `SQLFORMAT`) |
| Copiar estrutura | `CTAS tabela nova_tabela` (gera o `CREATE TABLE AS SELECT`) |
| Repetir uma consulta | `REPEAT 10 5` (dez vezes, a cada cinco segundos: acompanhar progresso) |
| Formatar SQL | `FORMAT BUFFER`, `FORMAT FILE entrada saida` |
| Barra de status | `SET STATUSBAR ON` |
| Migração de schema | `LIQUIBASE` / `LB` (e o comando `PROJECT` nas versões recentes) |

## SET SQLFORMAT

```sql
SET SQLFORMAT csv
SELECT * FROM departamentos;
SET SQLFORMAT insert
SELECT * FROM departamentos WHERE id_departamento = 10;
SET SQLFORMAT ansiconsole
SET SQLFORMAT
```

O último comando, sem valor, volta ao padrão. `ansiconsole` ajusta a largura das colunas aos dados e formata números; é o mais confortável para uso interativo. `insert` gera os comandos `INSERT` com os dados, útil para copiar poucas linhas entre bancos ou montar dados de teste. `loader` gera o formato do SQL*Loader.

Também funciona por comentário na própria consulta: `SELECT /*csv*/ * FROM departamentos;`, `/*json*/`, `/*insert*/`.

## Liquibase

O SQLcl inclui o Liquibase (controle de versão de schema: *changelogs* que descrevem as mudanças e uma tabela no banco que registra o que já foi aplicado):

```text
lb generate-schema          gera changelogs do schema atual
lb update -changelog-file controller.xml   aplica o que falta
lb status                   mostra o que ainda não foi aplicado
lb rollback-count 1         desfaz a última mudança registrada
```

Os nomes e opções dos comandos mudaram entre versões do SQLcl (de `lb genschema` para `lb generate-schema`, por exemplo). Confira `lb help` na versão instalada.

## SQL*Plus ou SQLcl?

| Situação | Escolha |
|---|---|
| Servidor do banco, sem Java, scripts antigos de agendador | SQL*Plus |
| Uso interativo no dia a dia | SQLcl |
| Exportar e importar CSV, gerar DDL e INSERTs | SQLcl |
| Pipeline de deploy com versionamento de schema | SQLcl com Liquibase |

Scripts escritos para SQL*Plus rodam no SQLcl quase sempre sem mudança. O inverso não vale para os comandos próprios do SQLcl (`INFO`, `DDL`, `SQLFORMAT`), que no SQL*Plus dão SP2-0734 (comando desconhecido).

## Documentação oficial

- [Oracle SQLcl — página do produto e download](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/)
- [Oracle SQLcl User's Guide](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/)
