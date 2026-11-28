# Controle de erro em script: WHENEVER SQLERROR, WHENEVER OSERROR, ERRORLOGGING

Por padrão, o SQL*Plus mostra o erro e **segue para o próximo comando**. Num script de deploy, isso significa que a tabela não foi criada, mas os 40 comandos seguintes rodam assim mesmo, falhando ou, pior, funcionando pela metade.

## WHENEVER

```sql
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
WHENEVER OSERROR  EXIT FAILURE
```

| Forma | Efeito |
|---|---|
| `WHENEVER SQLERROR EXIT [SUCCESS\|FAILURE\|WARNING\|n\|SQL.SQLCODE] [COMMIT\|ROLLBACK]` | Ao primeiro erro de SQL ou PL/SQL, encerra o SQL*Plus com o código indicado |
| `WHENEVER SQLERROR CONTINUE [COMMIT\|ROLLBACK\|NONE]` | Volta ao padrão: segue em frente |
| `WHENEVER OSERROR ...` | O mesmo para erros do sistema operacional (arquivo de `@` ou de `SPOOL` inexistente, sem permissão) |

- **Sempre diga `ROLLBACK` ou `COMMIT`.** Sem isso, `EXIT` faz o padrão do SQL*Plus, que é COMMIT: o que o script fez antes do erro fica confirmado.
- Vale para erros do banco (ORA-, PLS-), não para erros de comandos do próprio SQL*Plus (SP2-), como um `COLUMN` mal escrito.
- `SQL.SQLCODE` como código de saída: no Linux, o sistema só guarda de 0 a 255, então o ORA-00942 vira 942 mod 256 = 174. Para o agendador, basta saber que é diferente de 0; o detalhe fica no log (`SPOOL`).

## Padrão de script de deploy

```sql
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
WHENEVER OSERROR  EXIT FAILURE ROLLBACK
SET ECHO ON
SPOOL deploy_20261127.log

@@01-tabelas.sql
@@02-packages.sql
@@03-dados.sql

-- conferência de objetos inválidos antes de confirmar
SELECT object_name FROM user_objects WHERE status = 'INVALID';

COMMIT;
SPOOL OFF
EXIT SUCCESS
```

Lembre que DDL faz COMMIT implícito: o `ROLLBACK` do WHENEVER desfaz só o DML pendente desde o último DDL. Script que mistura DDL e DML não é atômico; planeje o retorno (scripts de rollback, flashback, backup) para esse caso.

Erro de compilação de PL/SQL (`CREATE PROCEDURE` com erro) **não é** erro para o WHENEVER: o objeto é criado como INVALID, com a mensagem "criado com erros de compilação", e o script segue. Confira `USER_ERRORS` ou objetos inválidos no fim, como no exemplo acima.

## SET ERRORLOGGING `[11g+]`

```sql
SET ERRORLOGGING ON
```

Grava cada erro do script numa tabela (`SPERRORLOG` no schema atual, criada na primeira vez), com o comando que falhou, a mensagem, o script e a linha. Útil para scripts que devem continuar apesar de erros e precisam de um relatório no fim. `SET ERRORLOGGING ON IDENTIFIER 'deploy-v2'` marca as linhas de uma execução.

## Documentação oficial

- [SQL*Plus User's Guide — WHENEVER SQLERROR](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/WHENEVER-SQLERROR.html)
- [SQL*Plus User's Guide — WHENEVER OSERROR](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/WHENEVER-OSERROR.html)
- [SQL*Plus User's Guide — SET ERRORLOGGING](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html)
