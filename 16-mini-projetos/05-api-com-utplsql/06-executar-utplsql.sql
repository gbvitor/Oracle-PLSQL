-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — formas de rodar a suite
-- Seção   : 16-mini-projetos
-- Versão  : 19c; utPLSQL 3.1 ou superior
-- Requer  : 05-suite-utplsql.sql já executado
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

-- 1. A suite inteira, relatório em texto (o padrão).
EXEC ut.run('test_api_pkg_clientes')

-- 2. Só um teste: package.procedure (no schema atual).
EXEC ut.run('test_api_pkg_clientes.versao_velha')

-- 2b. Tudo o que está sob um suitepath: o caminho começa com dois-pontos.
EXEC ut.run(':mini_projetos.api')

-- 3. Todas as suites do schema.
EXEC ut.run()

-- 4. Como consulta: útil em ferramentas que não mostram DBMS_OUTPUT.
SELECT * FROM TABLE(ut.run('test_api_pkg_clientes'));

-- 5. Relatório JUnit (XML), o formato que servidores de integração contínua leem.
SET PAGESIZE 0
SET LONG 1000000
SELECT * FROM TABLE(ut.run('test_api_pkg_clientes', ut_junit_reporter()));
SET PAGESIZE 100

-- 6. Cobertura de código da package testada, em HTML, gravada pelo SPOOL.
--    Mostra quais linhas de api_pkg_clientes os testes executaram.
SET PAGESIZE 0
SET LINESIZE 32767
SET TRIMSPOOL ON
SET FEEDBACK OFF
SPOOL cobertura-api.html
SELECT *
  FROM TABLE(ut.run('test_api_pkg_clientes',
                    ut_coverage_html_reporter(),
                    a_include_objects => ut_varchar2_list('API_PKG_CLIENTES')));
SPOOL OFF
SET FEEDBACK ON
SET LINESIZE 200
SET PAGESIZE 100
