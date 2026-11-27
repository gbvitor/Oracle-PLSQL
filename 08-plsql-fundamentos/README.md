# 08 — PL/SQL: fundamentos

A linguagem procedural do Oracle: estrutura de bloco, variáveis, controle de fluxo, cursores e tratamento de erro.

Todos os scripts usam `SET SERVEROUTPUT ON` e terminam cada bloco com `/` na linha seguinte ao `END;`. A saída esperada vem num comentário logo depois do `/`.

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Bloco anônimo: DECLARE, BEGIN, EXCEPTION, END; DBMS_OUTPUT e SERVEROUTPUT | [md](01-bloco-anonimo.md) | [sql](01-bloco-anonimo.sql) |
| 02 | Variáveis, constantes, tipos escalares, %TYPE, %ROWTYPE, SUBTYPE | [md](02-variaveis-e-tipos.md) | [sql](02-variaveis-e-tipos.sql) |
| 03 | SELECT INTO, NO_DATA_FOUND e TOO_MANY_ROWS | [md](03-select-into.md) | [sql](03-select-into.sql) |
| 04 | IF, ELSIF, ELSE e CASE em PL/SQL; CASE_NOT_FOUND | [md](04-if-e-case.md) | [sql](04-if-e-case.sql) |
| 05 | Laços: LOOP, WHILE, FOR, EXIT, CONTINUE, rótulos | [md](05-lacos.md) | [sql](05-lacos.sql) |
| 06 | Cursores implícitos: SQL%ROWCOUNT, SQL%FOUND, SQL%NOTFOUND | [md](06-cursores-implicitos.md) | [sql](06-cursores-implicitos.sql) |
| 07 | Cursores explícitos: OPEN, FETCH, CLOSE e atributos | [md](07-cursores-explicitos.md) | [sql](07-cursores-explicitos.sql) |
| 08 | Cursor FOR loop, cursor com parâmetro, FOR UPDATE e WHERE CURRENT OF | [md](08-cursor-for-loop.md) | [sql](08-cursor-for-loop.sql) |
| 09 | Exceções predefinidas, do usuário e PRAGMA EXCEPTION_INIT | [md](09-excecoes.md) | [sql](09-excecoes.sql) |
| 10 | RAISE, RAISE_APPLICATION_ERROR, SQLCODE e SQLERRM | [md](10-raise-e-sqlerrm.md) | [sql](10-raise-e-sqlerrm.sql) |
| 11 | Escopo, blocos aninhados, propagação de exceções e transação | [md](11-escopo-e-propagacao.md) | [sql](11-escopo-e-propagacao.sql) |
| 12 | Records: %ROWTYPE, TYPE RECORD, aninhados, atribuição e DML | [md](12-records.md) | [sql](12-records.sql) |

Continua em [09 — PL/SQL: avançado](../09-plsql-avancado/README.md): procedures, functions, packages, triggers, coleções e processamento em lote.
