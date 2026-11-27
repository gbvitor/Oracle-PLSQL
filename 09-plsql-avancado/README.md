# 09 — PL/SQL: avançado

Unidades armazenadas, processamento em lote, SQL dinâmico e recursos que aparecem em código de produção.

Objetos criados pelos scripts usam o prefixo `tmp_` e são removidos no fim de cada script.

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Procedures: IN, OUT, IN OUT, NOCOPY, DEFAULT, notação nomeada, objeto INVALID | [md](01-procedures.md) | [sql](01-procedures.sql) |
| 02 | Functions: uso em SQL e restrições, DETERMINISTIC, RESULT_CACHE, PRAGMA UDF, WITH FUNCTION | [md](02-functions.md) | [sql](02-functions.sql) |
| 03 | Packages: especificação e corpo, privados, estado, inicialização, overloading, ORA-04068 | [md](03-packages.md) | [sql](03-packages.sql) |
| 04 | Triggers DML: linha e instrução, BEFORE e AFTER, :NEW e :OLD, WHEN, ordem de disparo | [md](04-triggers.md) | [sql](04-triggers.sql) |
| 05 | Tabela mutante (ORA-04091) e compound trigger | [md](05-tabela-mutante.md) | [sql](05-tabela-mutante.sql) |
| 06 | Triggers INSTEAD OF e de sistema (DDL, LOGON) | [md](06-triggers-instead-of-e-sistema.md) | [sql](06-triggers-instead-of-e-sistema.sql) |

## Próximos tópicos

- [ ] 07 — Coleções: associative array, nested table, VARRAY; métodos
- [ ] 08 — BULK COLLECT, LIMIT e FORALL; SAVE EXCEPTIONS
- [ ] 09 — SQL dinâmico: EXECUTE IMMEDIATE, bind variables, DBMS_SQL
- [ ] 10 — REF CURSOR e SYS_REFCURSOR
- [ ] 11 — Pipelined table functions
- [ ] 12 — PRAGMA AUTONOMOUS_TRANSACTION (log de erro)
- [ ] 13 — Rastreamento de erro: DBMS_UTILITY.FORMAT_ERROR_BACKTRACE e UTL_CALL_STACK
- [ ] 14 — Direitos de execução: AUTHID DEFINER e CURRENT_USER
- [ ] 15 — Dependências, invalidação e recompilação
- [ ] 16 — Pacotes nativos úteis: DBMS_OUTPUT, DBMS_SESSION.SLEEP, UTL_FILE, DBMS_LOB
- [ ] 17 — Testes unitários com utPLSQL
