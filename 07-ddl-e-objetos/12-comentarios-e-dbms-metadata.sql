-- =============================================================================
-- Tópico : COMMENT ON e extração de DDL com DBMS_METADATA
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Os comandos SET são do SQL*Plus/SQLcl, para exibir o CLOB inteiro.
-- =============================================================================

SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET PAGESIZE 0
SET LINESIZE 32767

-- 1. Comentários do schema de exemplo (criados em 02-criar-schema.sql).
SELECT table_name, comments
  FROM user_tab_comments
 WHERE comments IS NOT NULL
 ORDER BY table_name;

SELECT table_name, column_name, comments
  FROM user_col_comments
 WHERE comments IS NOT NULL
 ORDER BY table_name, column_name;

-- Colunas sem comentário: o que falta documentar.
SELECT c.table_name, c.column_name
  FROM user_tab_columns  c
  JOIN user_col_comments m ON m.table_name = c.table_name AND m.column_name = c.column_name
 WHERE m.comments IS NULL
   AND c.table_name IN ('PEDIDOS', 'ITENS_PEDIDO')
 ORDER BY c.table_name, c.column_id;

-- 2. DDL de uma tabela com o formato padrão (inclui tablespace, storage...).
SELECT DBMS_METADATA.GET_DDL('TABLE', 'PEDIDOS') AS ddl FROM dual;

-- 3. DDL limpa e pronta para rodar em outro ambiente.
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'EMIT_SCHEMA', FALSE);
END;
/

-- Esperado: CREATE TABLE "PEDIDOS" (...) com as constraints inline e ";" no fim,
--           sem TABLESPACE nem STORAGE
SELECT DBMS_METADATA.GET_DDL('TABLE', 'PEDIDOS') AS ddl FROM dual;

-- 4. Objetos dependentes: índices, comentários e FKs da tabela.
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('INDEX',   'PEDIDOS') AS indices     FROM dual;
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('COMMENT', 'PEDIDOS') AS comentarios FROM dual;

-- Tabela sem trigger: a função dá erro em vez de devolver vazio.
-- Esperado: ORA-31608 (o objeto especificado do tipo TRIGGER não foi encontrado)
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('TRIGGER', 'PEDIDOS') AS triggers FROM dual;

-- 5. Outros tipos de objeto.
CREATE OR REPLACE VIEW tmp_vw_pedidos_abertos AS
SELECT id_pedido, id_cliente, data_pedido FROM pedidos WHERE status = 'ABERTO';

CREATE OR REPLACE FUNCTION tmp_fn_valor_liquido (
    p_quantidade NUMBER,
    p_preco      NUMBER,
    p_desconto   NUMBER
) RETURN NUMBER DETERMINISTIC IS
BEGIN
    RETURN ROUND(p_quantidade * p_preco * (1 - p_desconto / 100), 2);
END;
/

SELECT DBMS_METADATA.GET_DDL('VIEW',     'TMP_VW_PEDIDOS_ABERTOS') AS ddl_view   FROM dual;
SELECT DBMS_METADATA.GET_DDL('FUNCTION', 'TMP_FN_VALOR_LIQUIDO')   AS ddl_funcao FROM dual;
SELECT DBMS_METADATA.GET_DDL('INDEX',    'IX_PEDIDOS_DATA')        AS ddl_indice FROM dual;

-- Comparação: USER_SOURCE traz o código em linhas, sem o comando completo.
SELECT line, text FROM user_source WHERE name = 'TMP_FN_VALOR_LIQUIDO' ORDER BY line;

-- 6. Script do schema inteiro: todas as tabelas, depois as views.
--    Uma linha por objeto, já com ";" no fim, na ordem de criação.
SELECT DBMS_METADATA.GET_DDL(object_type, object_name) AS ddl
  FROM user_objects
 WHERE object_type IN ('TABLE', 'VIEW')
   AND object_name NOT LIKE 'BIN$%'
 ORDER BY CASE object_type WHEN 'TABLE' THEN 1 ELSE 2 END, created, object_name;

-- 7. Voltar o formato padrão da sessão.
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'DEFAULT');
END;
/

-- Limpeza
DROP FUNCTION tmp_fn_valor_liquido;
DROP VIEW tmp_vw_pedidos_abertos;

SET PAGESIZE 100
SET LINESIZE 200
