-- =============================================================================
-- Tópico : Objetos e código — USER_OBJECTS, USER_SOURCE, USER_PROCEDURES,
--          USER_ARGUMENTS, USER_ERRORS, DBMS_METADATA
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado; CREATE PROCEDURE
-- =============================================================================

COLUMN object_name    FORMAT A26
COLUMN procedure_name FORMAT A16
COLUMN argument_name  FORMAT A14
COLUMN texto          FORMAT A70

-- 1. Inventário por tipo.
-- Esperado: INDEX 18 | TABLE 7 (schema recém-instalado)
SELECT object_type, COUNT(*) AS objetos
  FROM user_objects
 WHERE object_name NOT LIKE 'BIN$%'
 GROUP BY object_type
 ORDER BY object_type;

-- Objetos para os próximos passos: uma package e uma procedure com erro.
CREATE OR REPLACE PACKAGE tmp_pkg_api_vendas IS
    FUNCTION valor_pedido (p_id_pedido IN NUMBER) RETURN NUMBER;
    PROCEDURE cancelar (p_id_pedido IN NUMBER, p_motivo IN VARCHAR2 DEFAULT NULL);
    PROCEDURE cancelar (p_id_cliente IN NUMBER, p_desde IN DATE);
END tmp_pkg_api_vendas;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_api_vendas IS
    FUNCTION valor_pedido (p_id_pedido IN NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2))
          INTO v
          FROM itens_pedido
         WHERE id_pedido = p_id_pedido;
        RETURN v;
    END valor_pedido;

    PROCEDURE cancelar (p_id_pedido IN NUMBER, p_motivo IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        UPDATE pedidos
           SET status = 'CANCELADO', observacao = NVL(p_motivo, observacao)
         WHERE id_pedido = p_id_pedido;
    END cancelar;

    PROCEDURE cancelar (p_id_cliente IN NUMBER, p_desde IN DATE) IS
    BEGIN
        UPDATE pedidos
           SET status = 'CANCELADO'
         WHERE id_cliente = p_id_cliente
           AND data_pedido >= p_desde
           AND status = 'ABERTO';
    END cancelar;
END tmp_pkg_api_vendas;
/

CREATE OR REPLACE PROCEDURE tmp_proc_quebrada IS
    v NUMBER;
BEGIN
    SELECT valor_total INTO v FROM pedidos WHERE id_pedido = 1001;
END tmp_proc_quebrada;
/
-- Esperado: "criado com erros de compilação" (pedidos não tem valor_total)

-- 2. Objetos criados ou alterados recentemente.
-- Esperado: TMP_PKG_API_VENDAS (PACKAGE e PACKAGE BODY) e TMP_PROC_QUEBRADA
SELECT object_name, object_type, status,
       TO_CHAR(created, 'DD/MM HH24:MI')       AS criado,
       TO_CHAR(last_ddl_time, 'DD/MM HH24:MI') AS ultimo_ddl
  FROM user_objects
 WHERE last_ddl_time > SYSDATE - 1 / 24
   AND object_type NOT IN ('TABLE', 'INDEX')
 ORDER BY last_ddl_time DESC;

-- 3. Objetos inválidos e o motivo.
-- Esperado: TMP_PROC_QUEBRADA | PROCEDURE | INVALID
SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID' ORDER BY 1;

-- Esperado: linha 4 | PL/SQL: ORA-00904: "VALOR_TOTAL": identificador inválido
--           linha 4 | PL/SQL: SQL Statement ignored
SELECT line, position, text AS texto
  FROM user_errors
 WHERE name = 'TMP_PROC_QUEBRADA'
 ORDER BY sequence;

-- 4. Pesquisar no código: onde ITENS_PEDIDO é usada?
-- Esperado: TMP_PKG_API_VENDAS | PACKAGE BODY | linha 7 | FROM itens_pedido
SELECT name, type, line, TRIM(text) AS texto
  FROM user_source
 WHERE UPPER(text) LIKE '%ITENS_PEDIDO%'
 ORDER BY name, type, line;

-- Quem altera o status para CANCELADO?
-- Esperado: duas linhas no PACKAGE BODY (linhas 15 e 22)
SELECT name, type, line, TRIM(text) AS texto
  FROM user_source
 WHERE UPPER(text) LIKE '%STATUS%=%''CANCELADO''%'
 ORDER BY name, type, line;

-- 5. Tamanho do código.
-- Esperado: TMP_PKG_API_VENDAS PACKAGE 5 | PACKAGE BODY 27 | TMP_PROC_QUEBRADA PROCEDURE 5
SELECT name, type, COUNT(*) AS linhas
  FROM user_source
 WHERE name LIKE 'TMP%'
 GROUP BY name, type
 ORDER BY name, type;

-- 6. A API da package: rotinas e parâmetros.
-- Esperado: CANCELAR overload 1 | CANCELAR overload 2 | VALOR_PEDIDO
SELECT object_name, procedure_name, overload, authid
  FROM user_procedures
 WHERE object_name = 'TMP_PKG_API_VENDAS'
   AND procedure_name IS NOT NULL
 ORDER BY procedure_name, overload;

-- Esperado:
--   CANCELAR      1  1 P_ID_PEDIDO  NUMBER   IN  N
--   CANCELAR      1  2 P_MOTIVO     VARCHAR2 IN  Y   (tem DEFAULT)
--   CANCELAR      2  1 P_ID_CLIENTE NUMBER   IN  N
--   CANCELAR      2  2 P_DESDE      DATE     IN  N
--   VALOR_PEDIDO     0 (retorno)    NUMBER   OUT N
--   VALOR_PEDIDO     1 P_ID_PEDIDO  NUMBER   IN  N
SELECT object_name AS rotina,
       overload,
       position,
       NVL(argument_name, '(retorno)') AS argument_name,
       data_type,
       in_out,
       defaulted
  FROM user_arguments
 WHERE package_name = 'TMP_PKG_API_VENDAS'
 ORDER BY object_name, overload, position;

-- 7. Código pela USER_SOURCE versus DDL completo pelo DBMS_METADATA.
-- USER_SOURCE: só o corpo do código, sem CREATE OR REPLACE.
SELECT TRIM(text) AS texto FROM user_source WHERE name = 'TMP_PROC_QUEBRADA' ORDER BY line;

-- DBMS_METADATA: o objeto inteiro, pronto para rodar ou versionar.
SET LONG 20000
SET PAGESIZE 0
SELECT DBMS_METADATA.GET_DDL('PACKAGE', 'TMP_PKG_API_VENDAS') AS ddl FROM dual;
SET PAGESIZE 14
-- Esperado: CREATE OR REPLACE EDITIONABLE PACKAGE "ESTUDO"."TMP_PKG_API_VENDAS" ...
--           seguido de CREATE OR REPLACE EDITIONABLE PACKAGE BODY ...

-- 8. Texto de view.
CREATE OR REPLACE VIEW tmp_vw_pedidos_abertos AS
SELECT id_pedido, id_cliente, data_pedido FROM pedidos WHERE status = 'ABERTO';

-- Esperado: SELECT id_pedido, id_cliente, data_pedido FROM pedidos WHERE status = 'ABERTO'
SELECT view_name, text FROM user_views WHERE view_name = 'TMP_VW_PEDIDOS_ABERTOS';

DROP VIEW tmp_vw_pedidos_abertos;
DROP PROCEDURE tmp_proc_quebrada;
DROP PACKAGE tmp_pkg_api_vendas;
