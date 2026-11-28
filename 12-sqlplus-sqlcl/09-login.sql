-- =============================================================================
-- Tópico : Modelo de login.sql (perfil do usuário do SQL*Plus e do SQLcl)
-- Seção  : 12-sqlplus-sqlcl
-- Versão : SQL*Plus 12.2+ e SQLcl
--
-- Uso: copie para uma pasta sua com o nome login.sql e aponte a variável:
--   Linux:   export ORACLE_PATH=$HOME/sqlplus
--   Windows: setx SQLPATH "C:\Users\voce\sqlplus"
-- A cada conexão, este arquivo roda depois do glogin.sql.
--
-- Pode também ser executado à mão para testar: @09-login.sql
-- =============================================================================

-- Durante a execução do perfil, não mostrar nada.
SET TERMOUT OFF

-- Saída legível.
SET LINESIZE 200
SET PAGESIZE 100
SET TRIMOUT ON
SET TRIMSPOOL ON
SET TAB OFF
SET LONG 100000
SET LONGCHUNKSIZE 100000

-- PL/SQL: saída do DBMS_OUTPUT ligada.
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WORD_WRAPPED

-- NULL visível e tempo de cada comando.
SET NULL '(nulo)'
SET TIMING OFF

-- Data e hora sempre com hora.
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI:SS';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'DD/MM/YYYY HH24:MI:SS.FF3';

-- Editor do comando EDIT (troque por notepad no Windows).
DEFINE _EDITOR = vi

-- Prompt com usuário e banco: saber sempre onde se está.
SET SQLPROMPT "_USER'@'_CONNECT_IDENTIFIER> "

-- Sair desfazendo o que não recebeu COMMIT (o padrão do SQL*Plus é confirmar).
SET EXITCOMMIT OFF

SET TERMOUT ON

-- Esperado ao conectar: prompt como ESTUDO@//localhost:1521/FREEPDB1>
--                       e SELECT SYSDATE FROM dual mostrando a hora
