# Folha de consulta — PL/SQL

Sintaxe resumida. Explicação nas seções 08 (fundamentos) e 09 (avançado).

## Bloco

```sql
[<<rotulo>>]
DECLARE
    v_total   NUMBER(12,2) := 0;
    v_nome    clientes.nome%TYPE;
    r_cli     clientes%ROWTYPE;
    c_limite  CONSTANT PLS_INTEGER := 100;
    e_regra   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_regra, -20001);
BEGIN
    NULL;
EXCEPTION
    WHEN NO_DATA_FOUND THEN ...
    WHEN e_regra THEN ...
    WHEN OTHERS THEN ... RAISE;
END [rotulo];
/
```

No SQL*Plus, a `/` numa linha sozinha executa o bloco. `SET SERVEROUTPUT ON` para ver o `DBMS_OUTPUT.PUT_LINE`.

## Tipos

| Tipo | Uso |
|---|---|
| `NUMBER(p,s)`, `PLS_INTEGER`, `BINARY_DOUBLE` | Número; `PLS_INTEGER` é inteiro rápido, de −2³¹ a 2³¹−1 |
| `VARCHAR2(n)`, `CHAR(n)`, `CLOB` | Texto; em PL/SQL, `VARCHAR2` vai até 32767 bytes |
| `DATE`, `TIMESTAMP`, `INTERVAL DAY TO SECOND` | Data e hora |
| `BOOLEAN` | `TRUE`, `FALSE`, `NULL`; só PL/SQL no 19c (em SQL a partir do 23ai) |
| `tabela.coluna%TYPE`, `tabela%ROWTYPE`, `cursor%ROWTYPE` | Ancorados no dicionário |
| `SUBTYPE t_valor IS NUMBER(12,2);` | Nome de domínio |

## Controle

```sql
IF cond THEN ... ELSIF cond THEN ... ELSE ... END IF;
CASE v WHEN 1 THEN ... WHEN 2 THEN ... ELSE ... END CASE;   -- sem ELSE e sem casar: CASE_NOT_FOUND
LOOP ... EXIT WHEN cond; ... END LOOP;
WHILE cond LOOP ... END LOOP;
FOR i IN 1 .. 10 LOOP ... END LOOP;        FOR i IN REVERSE 1 .. 10 LOOP ...
FOR r IN (SELECT ... ) LOOP ... r.coluna ... END LOOP;
CONTINUE WHEN cond;   GOTO rotulo;   NULL;
```

Limite NULL em `FOR i IN a .. b` levanta VALUE_ERROR; `FOR i IN v.FIRST .. v.LAST` em coleção vazia também (use `IF v.COUNT > 0` ou laço com `NEXT`).

## SQL dentro do PL/SQL

```sql
SELECT nome INTO v_nome FROM clientes WHERE id_cliente = 1;   -- 0 linhas: NO_DATA_FOUND; >1: TOO_MANY_ROWS
SELECT COUNT(*) INTO v_qtd FROM ... ;                          -- agregação nunca dá NO_DATA_FOUND
UPDATE ... ;  IF SQL%ROWCOUNT = 0 THEN ... END IF;
INSERT ... RETURNING id INTO v_id;
```

Atributos: `SQL%ROWCOUNT`, `SQL%FOUND`, `SQL%NOTFOUND` (último comando); `cursor%ISOPEN`, `%FOUND`, `%NOTFOUND`, `%ROWCOUNT`.

## Cursores (seção 08, tópicos 06 a 08)

```sql
CURSOR c_ped (p_cliente NUMBER) IS
    SELECT id_pedido, status FROM pedidos WHERE id_cliente = p_cliente [FOR UPDATE];

OPEN c_ped(1);
LOOP
    FETCH c_ped INTO v_id, v_status;
    EXIT WHEN c_ped%NOTFOUND;
    ... UPDATE pedidos SET ... WHERE CURRENT OF c_ped;
END LOOP;
CLOSE c_ped;

FOR r IN c_ped(1) LOOP ... END LOOP;          -- abre, lê e fecha sozinho
```

## Exceções (seção 08, tópicos 09 a 11)

| Exceção | ORA | Quando |
|---|---|---|
| `NO_DATA_FOUND` | 01403 (SQLCODE +100) | `SELECT INTO` sem linha; elemento inexistente de associative array |
| `TOO_MANY_ROWS` | 01422 | `SELECT INTO` com mais de uma linha |
| `DUP_VAL_ON_INDEX` | 00001 | Chave única violada |
| `VALUE_ERROR` | 06502 | Conversão, tamanho, limite NULL em `FOR` |
| `INVALID_NUMBER` | 01722 | Texto que não é número, em SQL |
| `ZERO_DIVIDE` | 01476 | Divisão por zero |
| `CASE_NOT_FOUND` | 06592 | `CASE` comando sem `ELSE` e sem casar |
| `CURSOR_ALREADY_OPEN` | 06511 | `OPEN` de cursor aberto |
| `INVALID_CURSOR` | 01001 | `FETCH`/`CLOSE` de cursor fechado |
| `COLLECTION_IS_NULL` | 06531 | Coleção não inicializada |
| `SUBSCRIPT_BEYOND_COUNT` | 06533 | Índice além de `COUNT` |
| `SUBSCRIPT_OUTSIDE_LIMIT` | 06532 | Índice fora do limite (≤ 0, acima do `LIMIT` do varray) |
| `ACCESS_INTO_NULL` | 06530 | Atributo de objeto nulo |
| `ROWTYPE_MISMATCH` | 06504 | Cursor variável com estrutura diferente |
| `TIMEOUT_ON_RESOURCE` | 00051 | Espera de recurso esgotada |
| `STORAGE_ERROR` / `PROGRAM_ERROR` | 06500 / 06501 | Memória / erro interno |

```sql
RAISE e_regra;
RAISE;                                                   -- relança a corrente (só no handler)
RAISE_APPLICATION_ERROR(-20001, 'Mensagem', TRUE);        -- -20000 a -20999; TRUE mantém a pilha
SQLCODE   SQLERRM                                        -- não usar direto em SQL: copie para variável
DBMS_UTILITY.FORMAT_ERROR_STACK
DBMS_UTILITY.FORMAT_ERROR_BACKTRACE                      -- linha onde o erro nasceu
DBMS_UTILITY.FORMAT_CALL_STACK
UTL_CALL_STACK.*                                         -- [12c+]
```

`WHEN OTHERS THEN NULL` esconde qualquer erro; `WHEN OTHERS` deve registrar e relançar.

## Procedures, functions, packages (seção 09, tópicos 01 a 03)

```sql
CREATE OR REPLACE PROCEDURE p (
    p_id     IN  NUMBER,
    p_total  OUT NUMBER,
    p_obs    IN OUT VARCHAR2,
    p_modo   IN  VARCHAR2 DEFAULT 'N'
) [AUTHID CURRENT_USER] IS
    v_local NUMBER;
BEGIN
    ...
END p;
/

CREATE OR REPLACE FUNCTION f (p_x IN NUMBER) RETURN NUMBER
    [DETERMINISTIC] [RESULT_CACHE] [PARALLEL_ENABLE] IS
    [PRAGMA UDF;]                                   -- [12c+] chamada a partir de SQL
BEGIN
    RETURN p_x * 2;
END f;
/

CREATE OR REPLACE PACKAGE pkg AS            -- especificação: o que é público
    c_versao CONSTANT VARCHAR2(5) := '1.0';
    e_erro   EXCEPTION;
    PROCEDURE p (p_id IN NUMBER);
    FUNCTION  f (p_id IN NUMBER) RETURN NUMBER;
END pkg;
/
CREATE OR REPLACE PACKAGE BODY pkg AS       -- corpo: implementação e privados
    g_estado NUMBER;                        -- estado por sessão
    PROCEDURE p (p_id IN NUMBER) IS BEGIN ... END p;
    FUNCTION  f (p_id IN NUMBER) RETURN NUMBER IS BEGIN RETURN 0; END f;
BEGIN
    g_estado := 0;                          -- inicialização, uma vez por sessão
END pkg;
/

EXEC p(1)                                   -- SQL*Plus
CALL p(1);                                  -- SQL
BEGIN p(p_id => 1); END;                    -- notação nomeada
```

## Triggers (seção 09, tópicos 04 a 06)

```sql
CREATE OR REPLACE TRIGGER trg
BEFORE INSERT OR UPDATE OF preco_unitario ON produtos
FOR EACH ROW
WHEN (NEW.preco_unitario < 0)
BEGIN
    IF INSERTING THEN ... ELSIF UPDATING('PRECO_UNITARIO') THEN ... END IF;
    :NEW.preco_unitario := 0;                 -- só em BEFORE de linha
END;
/
-- Também: AFTER, de comando (sem FOR EACH ROW), INSTEAD OF (views),
-- COMPOUND TRIGGER (um trigger com BEFORE/AFTER STATEMENT e EACH ROW), de sistema (LOGON, DDL).
ALTER TRIGGER trg DISABLE;   ALTER TABLE t DISABLE ALL TRIGGERS;
```

No `WHEN`, `NEW` e `OLD` vão sem os dois-pontos. Ler a própria tabela num trigger de linha: ORA-04091 (tabela mutante).

## Coleções (seção 09, tópico 07)

```sql
TYPE t_mapa  IS TABLE OF NUMBER INDEX BY VARCHAR2(30);   -- associative array: sem inicializar
TYPE t_lista IS TABLE OF NUMBER;                         -- nested table: inicializar
TYPE t_vetor IS VARRAY(10) OF NUMBER;                    -- varray: tamanho máximo
v_lista t_lista := t_lista(10, 20, 30);
v_lista.EXTEND;  v_lista(v_lista.LAST) := 40;
v_mapa('SP') := 1;
```

Métodos: `COUNT FIRST LAST NEXT(i) PRIOR(i) EXISTS(i) EXTEND[(n)] TRIM[(n)] DELETE[(i)] LIMIT`.

```sql
i := v_mapa.FIRST;
WHILE i IS NOT NULL LOOP ... i := v_mapa.NEXT(i); END LOOP;     -- percorre esparsa
SELECT * FROM TABLE(v_lista);                                   -- nested table de tipo SQL
```

## BULK COLLECT e FORALL (seção 09, tópico 08)

```sql
SELECT id_pedido BULK COLLECT INTO v_ids FROM pedidos WHERE ... ;
FETCH c BULK COLLECT INTO v_ids LIMIT 1000;                    -- em laço, para volume grande
FORALL i IN 1 .. v_ids.COUNT [SAVE EXCEPTIONS]
    UPDATE pedidos SET status = 'FATURADO' WHERE id_pedido = v_ids(i);
FORALL i IN INDICES OF v_ids ...        FORALL i IN VALUES OF v_idx ...
SQL%BULK_ROWCOUNT(i)                                           -- linhas de cada iteração
SQL%BULK_EXCEPTIONS(j).ERROR_INDEX / .ERROR_CODE                -- após ORA-24381
```

Com `LIMIT`, sair do laço por `EXIT WHEN v_ids.COUNT = 0`, não por `c%NOTFOUND` antes de processar (perderia o último bloco).

## SQL dinâmico e REF CURSOR (seção 09, tópicos 09 e 10)

```sql
EXECUTE IMMEDIATE 'UPDATE t SET x = :1 WHERE id = :2' USING v_x, v_id;
EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.SQL_OBJECT_NAME(v_tab) INTO v_qtd;
EXECUTE IMMEDIATE 'CREATE TABLE ...';                          -- DDL: COMMIT implícito

v_cur SYS_REFCURSOR;
OPEN v_cur FOR SELECT ... WHERE x = p_x;
OPEN v_cur FOR v_sql USING v_x;
FETCH v_cur INTO ... ;  CLOSE v_cur;
```

Valor sempre por bind (`:1`, `USING`); nome de objeto não aceita bind: validar com `DBMS_ASSERT`.

## Recursos avançados

```sql
PRAGMA AUTONOMOUS_TRANSACTION;          -- transação própria; precisa de COMMIT/ROLLBACK (tópico 12)
PRAGMA SERIALLY_REUSABLE;               -- estado da package só durante a chamada
FUNCTION f RETURN t_tab PIPELINED IS ... PIPE ROW(r); ... RETURN; END;   -- tópico 11
SELECT * FROM TABLE(f(...));
```

## Pacotes nativos mais usados (seção 09, tópico 16)

| Package | Para |
|---|---|
| `DBMS_OUTPUT` | `PUT_LINE` para o cliente |
| `DBMS_APPLICATION_INFO` | `SET_MODULE`, `SET_ACTION`: identificar a sessão em `V$SESSION` |
| `DBMS_SESSION` | `SLEEP` `[18c+]`, `SET_IDENTIFIER` |
| `DBMS_LOB` | `GETLENGTH`, `SUBSTR`, `INSTR`, `APPEND`, `CREATETEMPORARY` |
| `DBMS_SQL` | SQL dinâmico com número de colunas desconhecido |
| `DBMS_ASSERT` | Validar nomes antes de concatenar |
| `DBMS_RANDOM` | `VALUE`, `STRING` |
| `DBMS_UTILITY` | `FORMAT_ERROR_BACKTRACE`, `GET_TIME`, `COMMA_TO_TABLE` |
| `DBMS_SCHEDULER` | Jobs (seção 13, tópico 08) |
| `DBMS_METADATA` | `GET_DDL` |
| `DBMS_STATS` | Estatísticas (seção 11, tópico 05) |
| `UTL_FILE` | Arquivo no servidor (`DIRECTORY`) |
| `UTL_CALL_STACK` | Pilha de chamadas estruturada `[12c+]` |

## Compilar e depurar

```sql
SHOW ERRORS [PACKAGE BODY pkg]
SELECT line, position, text FROM user_errors WHERE name = 'PKG' ORDER BY sequence;
ALTER PACKAGE pkg COMPILE [BODY];   ALTER PROCEDURE p COMPILE;
EXEC DBMS_UTILITY.COMPILE_SCHEMA(USER, compile_all => FALSE)
SELECT object_name, object_type FROM user_objects WHERE status = 'INVALID';
SELECT DBMS_METADATA.GET_DDL('PACKAGE_BODY', 'PKG') FROM dual;
ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL';
```
