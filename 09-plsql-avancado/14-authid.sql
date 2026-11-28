-- =============================================================================
-- Tópico : AUTHID DEFINER e CURRENT_USER, roles em rotina armazenada,
--          ACCESSIBLE BY
-- Seção  : 09-plsql-avancado
-- Versão : 19c (ACCESSIBLE BY exige 12c+)
-- Requer : schema de exemplo (00-ambiente) e acesso de DBA para criar um
--          segundo usuário. Não funciona no FreeSQL (sem DBA).
--
-- Três sessões: [DBA], [ESTUDO] (dono do schema) e [LEITOR] (outro usuário).
-- Rode cada parte conectado como o usuário indicado no título.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- -----------------------------------------------------------------------------
-- Parte 1 [DBA]: segundo usuário e uma role com leitura de clientes.
-- -----------------------------------------------------------------------------
CREATE USER estudo_leitor IDENTIFIED BY "Leitor#2026"
    DEFAULT TABLESPACE users QUOTA 10M ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE PROCEDURE TO estudo_leitor;

CREATE ROLE tmp_role_leitura_clientes;
GRANT SELECT ON estudo.clientes TO tmp_role_leitura_clientes;
GRANT tmp_role_leitura_clientes TO estudo_leitor;

-- -----------------------------------------------------------------------------
-- Parte 2 [ESTUDO]: a mesma procedure nas duas versões.
-- -----------------------------------------------------------------------------
CREATE TABLE tmp_registro (
    quem  VARCHAR2(128) DEFAULT USER,
    texto VARCHAR2(100)
);

CREATE OR REPLACE PROCEDURE tmp_proc_definer (p_texto IN VARCHAR2)
    AUTHID DEFINER
IS
BEGIN
    INSERT INTO tmp_registro (texto) VALUES (p_texto);
    DBMS_OUTPUT.PUT_LINE('DEFINER | current_user = ' || SYS_CONTEXT('USERENV', 'CURRENT_USER')
        || ' | session_user = ' || SYS_CONTEXT('USERENV', 'SESSION_USER'));
END tmp_proc_definer;
/

CREATE OR REPLACE PROCEDURE tmp_proc_invoker (p_texto IN VARCHAR2)
    AUTHID CURRENT_USER
IS
BEGIN
    INSERT INTO tmp_registro (texto) VALUES (p_texto);
    DBMS_OUTPUT.PUT_LINE('INVOKER | current_user = ' || SYS_CONTEXT('USERENV', 'CURRENT_USER')
        || ' | session_user = ' || SYS_CONTEXT('USERENV', 'SESSION_USER'));
END tmp_proc_invoker;
/

GRANT EXECUTE ON tmp_proc_definer TO estudo_leitor;
GRANT EXECUTE ON tmp_proc_invoker TO estudo_leitor;

-- Nenhum grant em tmp_registro para o leitor.

-- -----------------------------------------------------------------------------
-- Parte 3 [LEITOR]: chamar as duas.
-- -----------------------------------------------------------------------------
EXEC estudo.tmp_proc_definer('pelo leitor, via definer')
-- Esperado: DEFINER | current_user = ESTUDO | session_user = ESTUDO_LEITOR
--           A linha foi para ESTUDO.TMP_REGISTRO, sem o leitor ter grant na tabela.

EXEC estudo.tmp_proc_invoker('pelo leitor, via invoker')
-- Esperado: ORA-00942 (a tabela ou view não existe): o nome TMP_REGISTRO foi
--           procurado no schema ESTUDO_LEITOR, que não tem essa tabela.

-- O leitor cria a própria tmp_registro: a mesma procedure grava no schema dele.
CREATE TABLE tmp_registro (
    quem  VARCHAR2(128) DEFAULT USER,
    texto VARCHAR2(100)
);

EXEC estudo.tmp_proc_invoker('pelo leitor, via invoker')
-- Esperado: INVOKER | current_user = ESTUDO_LEITOR | session_user = ESTUDO_LEITOR

COMMIT;

-- Esperado: 1 linha, "pelo leitor, via invoker" (na tabela do leitor)
SELECT quem, texto FROM tmp_registro;

-- Roles valem na consulta direta...
-- Esperado: 12
SELECT COUNT(*) FROM estudo.clientes;

-- ...mas não dentro de rotina DEFINER do leitor.
CREATE OR REPLACE FUNCTION tmp_fn_conta_clientes_estudo RETURN NUMBER IS
    v NUMBER;
BEGIN
    SELECT COUNT(*) INTO v FROM estudo.clientes;
    RETURN v;
END tmp_fn_conta_clientes_estudo;
/
-- Esperado: criada com erros; SHOW ERRORS mostra ORA-00942 / PL/SQL: SQL Statement ignored
SHOW ERRORS FUNCTION tmp_fn_conta_clientes_estudo

-- Com AUTHID CURRENT_USER e SQL dinâmico, a role de quem chama vale na execução.
CREATE OR REPLACE FUNCTION tmp_fn_conta_clientes_estudo RETURN NUMBER
    AUTHID CURRENT_USER
IS
    v NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM estudo.clientes' INTO v;
    RETURN v;
END tmp_fn_conta_clientes_estudo;
/

-- Esperado: 12
SELECT tmp_fn_conta_clientes_estudo FROM dual;

-- -----------------------------------------------------------------------------
-- Parte 4 [ESTUDO]: o que ficou na tabela do dono; ACCESSIBLE BY.
-- -----------------------------------------------------------------------------
-- Esperado: 1 linha, quem = ESTUDO_LEITOR, "pelo leitor, via definer"
--           (o DEFAULT USER registrou o usuário da sessão)
SELECT quem, texto FROM tmp_registro;

-- Rotina interna que só a API pode chamar.
CREATE OR REPLACE PACKAGE tmp_pkg_interno
    ACCESSIBLE BY (PACKAGE tmp_pkg_api)
IS
    FUNCTION calcular (p NUMBER) RETURN NUMBER;
END tmp_pkg_interno;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_interno IS
    FUNCTION calcular (p NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN p * 2;
    END calcular;
END tmp_pkg_interno;
/

CREATE OR REPLACE PACKAGE tmp_pkg_api IS
    FUNCTION dobro (p NUMBER) RETURN NUMBER;
END tmp_pkg_api;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_api IS
    FUNCTION dobro (p NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN tmp_pkg_interno.calcular(p);
    END dobro;
END tmp_pkg_api;
/

-- Esperado: 42
EXEC DBMS_OUTPUT.PUT_LINE(tmp_pkg_api.dobro(21))

-- Esperado: PLS-00904 (privilégio insuficiente para acessar o objeto TMP_PKG_INTERNO)
EXEC DBMS_OUTPUT.PUT_LINE(tmp_pkg_interno.calcular(21))

DROP PACKAGE tmp_pkg_api;
DROP PACKAGE tmp_pkg_interno;
DROP PROCEDURE tmp_proc_invoker;
DROP PROCEDURE tmp_proc_definer;
DROP TABLE tmp_registro PURGE;

-- -----------------------------------------------------------------------------
-- Parte 5 [DBA]: limpeza.
-- -----------------------------------------------------------------------------
DROP USER estudo_leitor CASCADE;
DROP ROLE tmp_role_leitura_clientes;
