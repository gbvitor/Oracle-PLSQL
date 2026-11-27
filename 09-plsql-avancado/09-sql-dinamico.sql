-- =============================================================================
-- Tópico : SQL dinâmico — EXECUTE IMMEDIATE, binds, injeção, DBMS_ASSERT,
--          filtros opcionais, DBMS_SQL e RETURN_RESULT
-- Seção  : 09-plsql-avancado
-- Versão : 19c (passo 10 exige 12c+)
-- Requer : schema de exemplo (00-ambiente); CREATE TABLE, CREATE PROCEDURE;
--          leitura de V$SQL no passo 6 (SELECT_CATALOG_ROLE, 00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. DDL dentro de PL/SQL só é possível com SQL dinâmico.
BEGIN
    CREATE TABLE tmp_din (id NUMBER);
END;
/
-- Esperado: PLS-00103 (encontrado o símbolo "CREATE"...)

BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE tmp_din (id NUMBER, descricao VARCHAR2(30))';
    DBMS_OUTPUT.PUT_LINE('Tabela criada');
END;
/
-- Esperado: Tabela criada

-- Tabela que não existia na compilação: o SQL que a usa também precisa ser dinâmico.
BEGIN
    EXECUTE IMMEDIATE 'INSERT INTO tmp_din VALUES (:id, :d)' USING 1, 'primeira';
    EXECUTE IMMEDIATE 'INSERT INTO tmp_din VALUES (:id, :d)' USING 2, 'segunda';
    DBMS_OUTPUT.PUT_LINE('Inseridas: 2');
END;
/
-- Esperado: Inseridas: 2

-- 2. INTO, USING e RETURNING INTO.
DECLARE
    v_qtd   PLS_INTEGER;
    v_desc  VARCHAR2(30);
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM pedidos WHERE status = :s' INTO v_qtd USING 'ENTREGUE';
    DBMS_OUTPUT.PUT_LINE('Entregues: ' || v_qtd);

    EXECUTE IMMEDIATE 'UPDATE tmp_din SET descricao = UPPER(descricao) WHERE id = :id RETURNING descricao INTO :d'
        USING 2 RETURNING INTO v_desc;
    DBMS_OUTPUT.PUT_LINE('Atualizada: ' || v_desc);
END;
/
-- Esperado: Entregues: 17 | Atualizada: SEGUNDA

ROLLBACK;

-- 3. Ponto e vírgula no fim do texto.
BEGIN
    EXECUTE IMMEDIATE 'SELECT 1 FROM dual;';
END;
/
-- Esperado: ORA-00933 ou ORA-00911 (caractere inválido)

-- 4. Injeção: concatenar valor versus bind.
CREATE OR REPLACE FUNCTION tmp_fn_conta_uf_concat (p_uf IN VARCHAR2) RETURN NUMBER IS
    v_qtd NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE uf = ''' || p_uf || '''' INTO v_qtd;
    RETURN v_qtd;
END tmp_fn_conta_uf_concat;
/

CREATE OR REPLACE FUNCTION tmp_fn_conta_uf_bind (p_uf IN VARCHAR2) RETURN NUMBER IS
    v_qtd NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE uf = :uf' INTO v_qtd USING p_uf;
    RETURN v_qtd;
END tmp_fn_conta_uf_bind;
/

DECLARE
    v_malicioso VARCHAR2(50) := 'SP'' OR ''1''=''1';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Valor recebido: ' || v_malicioso);
    DBMS_OUTPUT.PUT_LINE('Concatenado, SP:        ' || tmp_fn_conta_uf_concat('SP'));
    DBMS_OUTPUT.PUT_LINE('Concatenado, malicioso: ' || tmp_fn_conta_uf_concat(v_malicioso));
    DBMS_OUTPUT.PUT_LINE('Bind, malicioso:        ' || tmp_fn_conta_uf_bind(v_malicioso));
END;
/
-- Esperado:
--   Valor recebido: SP' OR '1'='1
--   Concatenado, SP:        3
--   Concatenado, malicioso: 12   (o filtro virou "uf = 'SP' OR '1'='1'")
--   Bind, malicioso:        0    (procurou uma UF com esse texto, não achou)

-- 5. Nome de tabela vindo de parâmetro: validar com DBMS_ASSERT.
CREATE OR REPLACE FUNCTION tmp_fn_conta_linhas (p_tabela IN VARCHAR2) RETURN NUMBER IS
    v_qtd NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.SQL_OBJECT_NAME(DBMS_ASSERT.SIMPLE_SQL_NAME(p_tabela))
        INTO v_qtd;
    RETURN v_qtd;
END tmp_fn_conta_linhas;
/

-- Esperado: 12 | 24
SELECT tmp_fn_conta_linhas('clientes') AS clientes, tmp_fn_conta_linhas('PEDIDOS') AS pedidos FROM dual;

-- Esperado: ORA-44003 (nome SQL inválido)
SELECT tmp_fn_conta_linhas('clientes WHERE 1=0 UNION SELECT 99 FROM dual') FROM dual;

-- Esperado: ORA-44002 (nome de objeto inválido: não existe)
SELECT tmp_fn_conta_linhas('tabela_inexistente') FROM dual;

-- 6. Parse: 100 textos com literal contra 1 texto com bind.
DECLARE
    v NUMBER;
BEGIN
    FOR i IN 1 .. 100 LOOP
        EXECUTE IMMEDIATE 'SELECT /* tmp_literal */ COUNT(*) FROM pedidos WHERE id_pedido = ' || (1000 + i) INTO v;
        EXECUTE IMMEDIATE 'SELECT /* tmp_bind */ COUNT(*) FROM pedidos WHERE id_pedido = :id' INTO v USING 1000 + i;
    END LOOP;
END;
/

-- Esperado: tmp_literal 100 instruções, 1 execução cada | tmp_bind 1 instrução, 100 execuções
SELECT CASE WHEN sql_text LIKE '%tmp_literal%' THEN 'tmp_literal' ELSE 'tmp_bind' END AS tipo,
       COUNT(*)        AS instrucoes,
       SUM(executions) AS execucoes
  FROM v$sql
 WHERE (sql_text LIKE 'SELECT /* tmp_literal */%' OR sql_text LIKE 'SELECT /* tmp_bind */%')
 GROUP BY CASE WHEN sql_text LIKE '%tmp_literal%' THEN 'tmp_literal' ELSE 'tmp_bind' END;

-- 7. Placeholder repetido: por posição em SQL, por nome em bloco PL/SQL.
DECLARE
    v NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE uf = :x OR cidade = :x' INTO v USING 'SP';
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SQL com :x duas vezes e um valor: ' || SQLERRM);
END;
/
-- Esperado: SQL com :x duas vezes e um valor: ORA-01008 (nem todas as variáveis são vinculadas)

DECLARE
    v NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE uf = :x OR cidade = :x' INTO v USING 'SP', 'SP';
    DBMS_OUTPUT.PUT_LINE('SQL com dois valores: ' || v);

    EXECUTE IMMEDIATE 'BEGIN :r := :x * :x; END;' USING OUT v, 7;
    DBMS_OUTPUT.PUT_LINE('Bloco PL/SQL, :x uma vez no USING: ' || v);
END;
/
-- Esperado: SQL com dois valores: 3 | Bloco PL/SQL, :x uma vez no USING: 49

-- 8. Filtros opcionais com condição neutra: sempre os mesmos binds.
CREATE OR REPLACE FUNCTION tmp_fn_conta_clientes (
    p_uf   IN VARCHAR2 DEFAULT NULL,
    p_tipo IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER IS
    v_sql VARCHAR2(500) := 'SELECT COUNT(*) FROM clientes WHERE 1 = 1';
    v_qtd NUMBER;
BEGIN
    IF p_uf IS NOT NULL THEN
        v_sql := v_sql || ' AND uf = :uf';
    ELSE
        v_sql := v_sql || ' AND (1 = 1 OR :uf IS NULL)';
    END IF;

    IF p_tipo IS NOT NULL THEN
        v_sql := v_sql || ' AND tipo_pessoa = :tipo';
    ELSE
        v_sql := v_sql || ' AND (1 = 1 OR :tipo IS NULL)';
    END IF;

    EXECUTE IMMEDIATE v_sql INTO v_qtd USING p_uf, p_tipo;
    RETURN v_qtd;
END tmp_fn_conta_clientes;
/

-- Esperado: todos 12 | SP 3 | pessoa física 5 | SP e física 1
SELECT tmp_fn_conta_clientes()                           AS todos,
       tmp_fn_conta_clientes(p_uf => 'SP')               AS sp,
       tmp_fn_conta_clientes(p_tipo => 'F')              AS fisica,
       tmp_fn_conta_clientes(p_uf => 'SP', p_tipo => 'F') AS sp_fisica
  FROM dual;

-- 9. DBMS_SQL: descrever as colunas de uma consulta qualquer.
DECLARE
    v_cursor  INTEGER;
    v_qtd_col INTEGER;
    v_cols    DBMS_SQL.DESC_TAB;
BEGIN
    v_cursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(v_cursor, 'SELECT * FROM departamentos', DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS(v_cursor, v_qtd_col, v_cols);

    DBMS_OUTPUT.PUT_LINE('Colunas: ' || v_qtd_col);
    FOR i IN 1 .. v_qtd_col LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(v_cols(i).col_name, 16)
            || ' tipo ' || v_cols(i).col_type
            || ' tamanho ' || v_cols(i).col_max_len);
    END LOOP;

    DBMS_SQL.CLOSE_CURSOR(v_cursor);
END;
/
-- Esperado:
--   Colunas: 3
--     ID_DEPARTAMENTO  tipo 2 tamanho 22
--     NOME             tipo 1 tamanho 60
--     CIDADE           tipo 1 tamanho 60
--   (tipo 1 = VARCHAR2, 2 = NUMBER, 12 = DATE, 96 = CHAR)

-- 10. [12c+] DBMS_SQL.RETURN_RESULT: devolver um SELECT ao cliente.
CREATE OR REPLACE PROCEDURE tmp_proc_pedidos_cliente (p_id_cliente IN NUMBER) IS
    v_rc SYS_REFCURSOR;
BEGIN
    OPEN v_rc FOR
        SELECT id_pedido, data_pedido, status
          FROM pedidos
         WHERE id_cliente = p_id_cliente
         ORDER BY id_pedido;
    DBMS_SQL.RETURN_RESULT(v_rc);
END tmp_proc_pedidos_cliente;
/

-- Esperado: "ResultSet #1" com os pedidos 1007 (CANCELADO) e 1018 (ENTREGUE)
EXEC tmp_proc_pedidos_cliente(8)

DROP PROCEDURE tmp_proc_pedidos_cliente;
DROP FUNCTION tmp_fn_conta_clientes;
DROP FUNCTION tmp_fn_conta_linhas;
DROP FUNCTION tmp_fn_conta_uf_bind;
DROP FUNCTION tmp_fn_conta_uf_concat;
DROP TABLE tmp_din PURGE;
