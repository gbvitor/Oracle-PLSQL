-- =============================================================================
-- Instala (ou reinstala) o schema de exemplo de uma vez.
-- Uso no SQL*Plus ou SQLcl, conectado como o usuário de estudo:
--     SQL> @instalar.sql
-- No FreeSQL, rode 99, 02, 03 e 04 colando um de cada vez.
-- =============================================================================

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET LINESIZE 200
SET PAGESIZE 100
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Removendo schema anterior (se houver)
@@99-remover-schema.sql

PROMPT == Criando tabelas
@@02-criar-schema.sql

PROMPT == Carregando dados
@@03-carregar-dados.sql

WHENEVER SQLERROR CONTINUE
SET FEEDBACK ON

PROMPT == Conferindo carga
COLUMN verificacao FORMAT A35
COLUMN situacao    FORMAT A10
@@04-conferir-carga.sql
