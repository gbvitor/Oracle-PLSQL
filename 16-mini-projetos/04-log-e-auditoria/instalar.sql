-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — instalação completa
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Uso no SQL*Plus ou SQLcl, a partir desta pasta:
--     SQL> @instalar.sql
-- Remove a versão anterior, cria tudo, roda a demonstração e os testes de aceite.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET LINESIZE 200
SET PAGESIZE 100

PROMPT == Removendo instalação anterior (se houver)
@@99-remover.sql

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Tabelas
@@01-tabelas.sql

PROMPT == Package de log
@@02-pacote-log.sql

PROMPT == Package de auditoria
@@03-pacote-auditoria.sql

PROMPT == Demonstração
@@04-demonstracao.sql

WHENEVER SQLERROR CONTINUE
SET FEEDBACK ON

PROMPT == Testes de aceite
@@05-testes-de-aceite.sql
