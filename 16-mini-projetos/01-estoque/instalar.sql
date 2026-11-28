-- =============================================================================
-- Projeto : 01 — Controle de estoque — instalação completa
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Uso no SQL*Plus ou SQLcl, a partir desta pasta:
--     SQL> @instalar.sql
-- Remove a versão anterior, cria tudo, carrega o exemplo e roda os testes de aceite.
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

PROMPT == Package
@@02-pacote.sql

PROMPT == Views
@@03-views.sql

PROMPT == Carga de exemplo
@@04-carga.sql

WHENEVER SQLERROR CONTINUE
SET FEEDBACK ON

PROMPT == Testes de aceite
@@05-testes-de-aceite.sql
