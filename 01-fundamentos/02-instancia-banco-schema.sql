-- =============================================================================
-- Tópico : Instância, banco, schema e usuário — onde estou conectado
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : qualquer conexão; as consultas a V$ exigem SELECT_CATALOG_ROLE
--          (o usuário de estudo já tem). No FreeSQL, só a consulta 1 funciona.
-- =============================================================================

-- 1. Contexto da sessão.
SELECT SYS_CONTEXT('USERENV', 'CON_NAME')       AS container,
       SYS_CONTEXT('USERENV', 'SESSION_USER')   AS usuario,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS schema_atual,
       SYS_CONTEXT('USERENV', 'DB_NAME')        AS banco,
       SYS_CONTEXT('USERENV', 'INSTANCE_NAME')  AS instancia,
       SYS_CONTEXT('USERENV', 'SERVICE_NAME')   AS servico
  FROM dual;

-- 2. Versão do banco.
SELECT banner_full FROM v$version;

-- 3. Instância: nome, servidor, status e desde quando está no ar.
SELECT instance_name, host_name, version, status, startup_time
  FROM v$instance;

-- 4. Contêineres visíveis a partir da sessão.
--    Conectado num PDB, aparece só o próprio PDB.
SELECT con_id, name, open_mode
  FROM v$containers;

-- 5. Usuário e schema são a mesma coisa: os objetos do usuário conectado.
SELECT object_type, COUNT(*) AS quantidade
  FROM user_objects
 GROUP BY object_type
 ORDER BY object_type;

-- 6. CURRENT_SCHEMA muda só a resolução de nomes, não os privilégios.
ALTER SESSION SET CURRENT_SCHEMA = sys;

SELECT SYS_CONTEXT('USERENV', 'SESSION_USER')   AS usuario,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS schema_atual
  FROM dual;

-- Agora "clientes" é procurada no schema SYS. Esperado: ORA-00942.
SELECT COUNT(*) FROM clientes;

-- Com o schema explícito, funciona.
SELECT COUNT(*) FROM estudo.clientes;

-- Voltar ao schema do próprio usuário.
ALTER SESSION SET CURRENT_SCHEMA = estudo;
