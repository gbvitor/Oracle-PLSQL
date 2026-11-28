-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — instalação completa
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Uso no SQL*Plus ou SQLcl, a partir desta pasta:
--     SQL> @instalar.sql
-- Remove a versão anterior, cria tudo, carrega o exemplo e roda os testes sem
-- framework. Se o utPLSQL estiver instalado, cria e roda também a suite.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET LINESIZE 200
SET PAGESIZE 100

PROMPT == Removendo instalação anterior (se houver)
@@99-remover.sql

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Tabela
@@01-tabelas.sql

PROMPT == Package
@@02-pacote.sql

PROMPT == Carga de exemplo
@@03-carga.sql

WHENEVER SQLERROR CONTINUE
SET FEEDBACK ON

PROMPT == Testes de aceite sem framework
@@04-testes-de-aceite.sql

-- Escolhe o script seguinte conforme o utPLSQL exista ou não: a coluna vira a
-- variável de substituição script_suite, usada no comando @@ logo abaixo.
SET DEFINE ON
COLUMN script_suite NEW_VALUE script_suite NOPRINT
SELECT CASE WHEN COUNT(*) > 0 THEN '05-suite-utplsql.sql' ELSE 'aviso-sem-utplsql.sql' END AS script_suite
  FROM all_objects
 WHERE object_name = 'UT'
   AND object_type IN ('PACKAGE', 'SYNONYM');

PROMPT == Suite utPLSQL (se disponível)
@@&script_suite
