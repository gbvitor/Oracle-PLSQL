-- =============================================================================
-- Tópico : Dependências, invalidação e recompilação
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE VIEW, CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- Cadeia: tabela <- view <- procedure <- package; e uma function direto na tabela.
CREATE TABLE tmp_dep_clientes AS SELECT id_cliente, nome, uf FROM clientes;

CREATE OR REPLACE VIEW tmp_dep_v_clientes AS
SELECT id_cliente, nome, uf FROM tmp_dep_clientes;

CREATE OR REPLACE PROCEDURE tmp_dep_proc_listar (p_uf IN VARCHAR2) IS
BEGIN
    FOR r IN (SELECT nome FROM tmp_dep_v_clientes WHERE uf = p_uf ORDER BY nome) LOOP
        DBMS_OUTPUT.PUT_LINE(r.nome);
    END LOOP;
END tmp_dep_proc_listar;
/

CREATE OR REPLACE FUNCTION tmp_dep_fn_nome (p_id IN NUMBER) RETURN VARCHAR2 IS
    v_nome tmp_dep_clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM tmp_dep_clientes WHERE id_cliente = p_id;
    RETURN v_nome;
END tmp_dep_fn_nome;
/

CREATE OR REPLACE PACKAGE tmp_dep_pkg IS
    PROCEDURE relatorio_sp;
END tmp_dep_pkg;
/

CREATE OR REPLACE PACKAGE BODY tmp_dep_pkg IS
    PROCEDURE relatorio_sp IS
    BEGIN
        tmp_dep_proc_listar('SP');
    END relatorio_sp;
END tmp_dep_pkg;
/

-- Consulta de situação usada em todo o script.
COLUMN object_name FORMAT A22
COLUMN object_type FORMAT A13

-- 1. Dependências registradas.
-- Esperado:
--   TMP_DEP_FN_NOME      FUNCTION     -> TMP_DEP_CLIENTES   TABLE
--   TMP_DEP_PKG          PACKAGE BODY -> TMP_DEP_PKG        PACKAGE
--   TMP_DEP_PKG          PACKAGE BODY -> TMP_DEP_PROC_LISTAR PROCEDURE
--   TMP_DEP_PROC_LISTAR  PROCEDURE    -> TMP_DEP_V_CLIENTES  VIEW
--   TMP_DEP_V_CLIENTES   VIEW         -> TMP_DEP_CLIENTES   TABLE
--   (além de dependências de pacotes do sistema, como STANDARD e DBMS_OUTPUT, filtradas aqui)
SELECT name, type, referenced_name, referenced_type
  FROM user_dependencies
 WHERE name LIKE 'TMP_DEP%'
   AND referenced_owner = USER
 ORDER BY name, type, referenced_name;

-- 2. Coluna nova: dependência fina, nada fica inválido.
ALTER TABLE tmp_dep_clientes ADD email VARCHAR2(120);

-- Esperado: todos VALID
SELECT object_name, object_type, status FROM user_objects WHERE object_name LIKE 'TMP_DEP%' ORDER BY 1, 2;

-- 3. Mudar o tamanho de uma coluna usada: dependentes ficam INVALID.
ALTER TABLE tmp_dep_clientes MODIFY nome VARCHAR2(200);

-- Esperado: TMP_DEP_V_CLIENTES, TMP_DEP_PROC_LISTAR e TMP_DEP_FN_NOME INVALID;
--           a tabela e a package VALID (o corpo pode aparecer INVALID ou não, conforme a versão)
SELECT object_name, object_type, status FROM user_objects WHERE object_name LIKE 'TMP_DEP%' ORDER BY 1, 2;

-- Recompilação automática no primeiro uso.
EXEC tmp_dep_pkg.relatorio_sp
-- Esperado: Fernanda Araujo | Papelaria Central Ltda | Tech Solucoes ME

-- Esperado: a cadeia usada voltou a VALID; TMP_DEP_FN_NOME continua INVALID (ninguém a chamou)
SELECT object_name, object_type, status FROM user_objects WHERE object_name LIKE 'TMP_DEP%' ORDER BY 1, 2;

-- 4. Listar e recompilar os inválidos do schema.
-- Esperado: FUNCTION TMP_DEP_FN_NOME
SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' AND object_name LIKE 'TMP_DEP%';

EXEC DBMS_UTILITY.COMPILE_SCHEMA(schema => USER, compile_all => FALSE)

-- Esperado: nenhuma linha
SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' AND object_name LIKE 'TMP_DEP%';

-- 5. Corpo de package recompilado não invalida quem chama; assinatura alterada invalida.
CREATE OR REPLACE PROCEDURE tmp_dep_proc_chamador IS
BEGIN
    tmp_dep_pkg.relatorio_sp;
END tmp_dep_proc_chamador;
/

-- Corpo novo, mesma especificação.
CREATE OR REPLACE PACKAGE BODY tmp_dep_pkg IS
    PROCEDURE relatorio_sp IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-- Clientes de SP');
        tmp_dep_proc_listar('SP');
    END relatorio_sp;
END tmp_dep_pkg;
/

-- Esperado: VALID
SELECT status FROM user_objects WHERE object_name = 'TMP_DEP_PROC_CHAMADOR';

-- Especificação com item novo no fim.
CREATE OR REPLACE PACKAGE tmp_dep_pkg IS
    PROCEDURE relatorio_sp;
    PROCEDURE relatorio_uf (p_uf IN VARCHAR2);
END tmp_dep_pkg;
/

-- Esperado: normalmente VALID (dependência fina: o chamador não usa o item novo)
SELECT status FROM user_objects WHERE object_name = 'TMP_DEP_PROC_CHAMADOR';

-- Especificação com a assinatura do item usado alterada.
CREATE OR REPLACE PACKAGE tmp_dep_pkg IS
    PROCEDURE relatorio_sp (p_titulo IN VARCHAR2);
    PROCEDURE relatorio_uf (p_uf IN VARCHAR2);
END tmp_dep_pkg;
/

-- Esperado: INVALID
SELECT status FROM user_objects WHERE object_name = 'TMP_DEP_PROC_CHAMADOR';

-- A recompilação falha: a chamada não bate com a assinatura nova.
ALTER PROCEDURE tmp_dep_proc_chamador COMPILE;
-- Esperado: "Advertência: Procedimento alterado com erros de compilação"
SHOW ERRORS PROCEDURE tmp_dep_proc_chamador
-- Esperado: PLS-00306 (número ou tipos de argumentos errados na chamada para 'RELATORIO_SP')

-- 6. Árvore de quem depende da tabela, direta e indiretamente (análise de impacto).
-- Esperado:
--   TMP_DEP_CLIENTES (TABLE)
--     TMP_DEP_FN_NOME (FUNCTION)
--     TMP_DEP_V_CLIENTES (VIEW)
--       TMP_DEP_PROC_LISTAR (PROCEDURE)
--         TMP_DEP_PKG (PACKAGE BODY)
SELECT LPAD(' ', 2 * (LEVEL - 1)) || name || ' (' || type || ')' AS dependente
  FROM (SELECT name, type, referenced_name, referenced_type
          FROM user_dependencies
         WHERE referenced_owner = USER
        UNION ALL
        SELECT 'TMP_DEP_CLIENTES', 'TABLE', NULL, NULL FROM dual)
 START WITH name = 'TMP_DEP_CLIENTES' AND referenced_name IS NULL
CONNECT BY NOCYCLE PRIOR name = referenced_name AND PRIOR type = referenced_type
 ORDER SIBLINGS BY name;

-- 7. SQL dinâmico não aparece como dependência.
CREATE OR REPLACE FUNCTION tmp_dep_fn_dinamica RETURN NUMBER IS
    v NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM tmp_dep_clientes' INTO v;
    RETURN v;
END tmp_dep_fn_dinamica;
/

-- Esperado: nenhuma linha com TMP_DEP_CLIENTES (só dependências de sistema, se houver)
SELECT referenced_name, referenced_type
  FROM user_dependencies
 WHERE name = 'TMP_DEP_FN_DINAMICA'
   AND referenced_owner = USER;

DROP FUNCTION tmp_dep_fn_dinamica;
DROP PROCEDURE tmp_dep_proc_chamador;
DROP PACKAGE tmp_dep_pkg;
DROP FUNCTION tmp_dep_fn_nome;
DROP PROCEDURE tmp_dep_proc_listar;
DROP VIEW tmp_dep_v_clientes;
DROP TABLE tmp_dep_clientes PURGE;
