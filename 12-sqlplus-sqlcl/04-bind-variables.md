# Bind variables no SQL*Plus: VARIABLE, EXEC, PRINT

Variável de ligação (bind) declarada no cliente e passada ao banco separada do texto do comando. É o jeito de testar no SQL*Plus uma consulta exatamente como a aplicação a executa (`WHERE id = :id`), com o mesmo cursor reaproveitado.

## Comandos

| Comando | Faz |
|---|---|
| `VARIABLE nome tipo` (ou `VAR`) | Declara. Tipos: `NUMBER`, `VARCHAR2(n)`, `CHAR(n)`, `NCHAR`, `CLOB`, `NCLOB`, `BLOB` `[12c+]`, `REFCURSOR`, `BINARY_FLOAT`, `BINARY_DOUBLE`, `BOOLEAN` `[23ai+]` |
| `VARIABLE` | Lista as declaradas |
| `EXEC :nome := valor` | Atribui (é um bloco PL/SQL de uma linha) |
| `VARIABLE nome tipo = valor` `[12.2+]` | Declara já com valor |
| `PRINT nome` / `PRINT` | Mostra o valor de uma / de todas |
| `SET AUTOPRINT ON` | Mostra automaticamente as variáveis usadas depois de cada `EXEC` ou bloco |

Uso: `:nome` em SQL e em blocos PL/SQL anônimos.

## Diferenças em relação à substituição

- **Não existe `DATE`**: declare `VARCHAR2` e converta (`TO_DATE(:data, 'YYYY-MM-DD')`), como a maioria das aplicações faria com uma data vinda de tela.
- Não troca nomes de objeto ou partes do comando; só valores.
- O tipo importa: bind `NUMBER` comparado a coluna `VARCHAR2` causa conversão da coluna e ignora o índice (seção 11, tópicos 03 e 06). Declare o bind com o tipo da coluna.
- `REFCURSOR` recebe o resultado de uma procedure ou function que devolve cursor (seção 09, tópico 10) e `PRINT` lê e fecha.

## Bind dentro de PL/SQL anônimo

```sql
VARIABLE total NUMBER
BEGIN
    SELECT SUM(valor) INTO :total FROM ...;
END;
/
PRINT total
```

É a forma de tirar um valor de um bloco PL/SQL para usá-lo nos comandos seguintes do script. Para usar o valor numa variável de substituição (nome de arquivo, PROMPT), passe por `COLUMN ... NEW_VALUE` com `SELECT :total AS x FROM dual`.

## Documentação oficial

- [SQL*Plus User's Guide — Using Bind Variables](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/using-scripts-in-SQL-Plus.html)
- [SQL*Plus User's Guide — VARIABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/VARIABLE.html)
