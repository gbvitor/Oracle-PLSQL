# 12 — SQL*Plus e SQLcl

Os clientes de linha de comando do Oracle: execução de scripts, formatação de saída e recursos próprios do SQLcl.

Os scripts desta seção são para rodar no SQL*Plus (ou no SQLcl, que aceita os mesmos comandos), de preferência como script (`@arquivo`): alguns comandos, como `SET TERMOUT OFF`, só funcionam assim. O tópico 10 usa comandos que só existem no SQLcl. Ao contrário do resto do repositório, aqui o caractere de substituição aparece no código de propósito (tópicos 02 a 06); continua fora dos comentários.

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Conexão: EZCONNECT, TNS, wallet, CONNECT e DISCONNECT, COMMIT implícito, erros de conexão | [md](01-conexao.md) | [sql](01-conexao.sql) |
| 02 | Executar scripts: `@`, `@@`, START, parâmetros posicionais, script mestre | [md](02-executar-scripts.md) | [sql](02-executar-scripts.sql), [filho](02-relatorio-cliente.sql) |
| 03 | Variáveis de substituição: DEFINE, UNDEFINE, ACCEPT, VERIFY, NEW_VALUE, o caractere em textos | [md](03-variaveis-de-substituicao.md) | [sql](03-variaveis-de-substituicao.sql) |
| 04 | Bind variables: VARIABLE, EXEC, PRINT, AUTOPRINT, REFCURSOR | [md](04-bind-variables.md) | [sql](04-bind-variables.sql) |
| 05 | Formatação: LINESIZE, PAGESIZE, COLUMN, NULL, BREAK, COMPUTE, TTITLE, MARKUP | [md](05-formatacao.md) | [sql](05-formatacao.sql) |
| 06 | SPOOL: CSV moderno e clássico, relatório texto, nome com data, acentos e NLS_LANG | [md](06-spool.md) | [sql](06-spool.sql) |
| 07 | Controle de erro: WHENEVER SQLERROR e OSERROR, script de deploy, SET ERRORLOGGING | [md](07-whenever-sqlerror.md) | [sql](07-whenever-sqlerror.sql) |
| 08 | DESCRIBE, SHOW ERRORS, SHOW PARAMETER, SHOW RECYCLEBIN e outros | [md](08-describe-e-show.md) | [sql](08-describe-e-show.sql) |
| 09 | login.sql e glogin.sql: onde ficam, a mudança do 12.2, o que colocar | [md](09-login-sql.md) | [modelo](09-login.sql) |
| 10 | SQLcl: SQLFORMAT, DDL, INFO, HISTORY, ALIAS, LOAD, UNLOAD, Liquibase | [md](10-sqlcl.md) | [sql](10-sqlcl.sql) |

Continua em [13 — Administração](../13-administracao/README.md).
