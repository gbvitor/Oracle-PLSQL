-- =============================================================================
-- Tópico : DESCRIBE e SHOW — estrutura de tabela e de package, erros de
--          compilação, parâmetros, lixeira, configurações
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus ou SQLcl)
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
-- =============================================================================

-- 1. DESCRIBE de tabela.
DESC clientes
-- Esperado:
--   Name             Null?    Type
--   ---------------- -------- -------------
--   ID_CLIENTE       NOT NULL NUMBER(6)
--   NOME             NOT NULL VARCHAR2(100)
--   TIPO_PESSOA      NOT NULL CHAR(1)
--   DOCUMENTO        NOT NULL VARCHAR2(14)
--   EMAIL                     VARCHAR2(120)
--   CIDADE           NOT NULL VARCHAR2(60)
--   UF               NOT NULL CHAR(2)
--   DATA_CADASTRO    NOT NULL DATE
--   LIMITE_CREDITO            NUMBER(12,2)
--   ATIVO            NOT NULL CHAR(1)

-- 2. DESCRIBE de package: a API sem abrir o código.
CREATE OR REPLACE PACKAGE tmp_pkg_desc IS
    FUNCTION valor_pedido (p_id_pedido IN NUMBER) RETURN NUMBER;
    PROCEDURE cancelar (p_id_pedido IN NUMBER, p_motivo IN VARCHAR2 DEFAULT NULL);
END tmp_pkg_desc;
/

DESC tmp_pkg_desc
-- Esperado:
--   PROCEDURE CANCELAR
--    Argument Name   Type       In/Out Default?
--    P_ID_PEDIDO     NUMBER     IN
--    P_MOTIVO        VARCHAR2   IN     DEFAULT
--   FUNCTION VALOR_PEDIDO RETURNS NUMBER
--    Argument Name   Type       In/Out Default?
--    P_ID_PEDIDO     NUMBER     IN
--   (a ordem das rotinas pode variar com a versão do cliente)

-- 3. DESCRIBE de uma package do Oracle.
DESC DBMS_SESSION
-- Esperado: a lista de rotinas (SET_IDENTIFIER, SLEEP, ...), cada uma com os parâmetros

-- 4. SHOW ERRORS: logo depois da compilação e depois, pelo nome.
CREATE OR REPLACE PACKAGE BODY tmp_pkg_desc IS
    FUNCTION valor_pedido (p_id_pedido IN NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT SUM(valor_total) INTO v FROM pedidos WHERE id_pedido = p_id_pedido;
        RETURN v;
    END valor_pedido;

    PROCEDURE cancelar (p_id_pedido IN NUMBER, p_motivo IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        UPDATE pedidos SET status = 'CANCELADO' WHERE id_pedido = p_id_pedido;
    END cancelar;
END tmp_pkg_desc;
/
-- Esperado: "Advertência: Corpo de Pacote criado com erros de compilação."

SHOW ERRORS
-- Esperado:
--   LINE/COL ERROR
--   5/9      PL/SQL: SQL Statement ignored
--   5/20     PL/SQL: ORA-00904: "VALOR_TOTAL": identificador inválido

SHOW ERRORS PACKAGE BODY tmp_pkg_desc
-- Esperado: a mesma lista, agora pelo nome (funciona em qualquer momento)

DROP PACKAGE tmp_pkg_desc;

-- 5. SHOW de sessão e de cliente.
SHOW USER
SHOW CON_NAME
SHOW RELEASE
-- Esperado: o número da versão do SQL*Plus (por exemplo 1903000000 para 19.3)

SHOW LINESIZE
SHOW AUTOCOMMIT
-- Esperado: linesize 80 | autocommit OFF

-- 6. Parâmetros do banco (exige leitura de V$PARAMETER).
SHOW PARAMETER nls_date
-- Esperado: nls_date_format e nls_date_language, com tipo e valor

SHOW PARAMETER optimizer_mode
-- Esperado: optimizer_mode string ALL_ROWS

-- 7. Lixeira.
CREATE TABLE tmp_lixeira (id NUMBER);
DROP TABLE tmp_lixeira;

SHOW RECYCLEBIN
-- Esperado: TMP_LIXEIRA com o nome interno BIN$...$0, tipo TABLE e a hora do DROP

FLASHBACK TABLE tmp_lixeira TO BEFORE DROP;
-- Esperado: "Flashback concluído." e a tabela de volta

DROP TABLE tmp_lixeira PURGE;
-- PURGE não passa pela lixeira

-- 8. Todas as configurações SET (longa).
-- SHOW ALL
