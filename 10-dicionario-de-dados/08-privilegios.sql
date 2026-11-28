-- =============================================================================
-- Tópico : Privilégios — de sistema, de objeto, por role, efetivos na sessão,
--          cotas e o roteiro de "por que não consigo acessar"
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : usuário criado por 00-ambiente/01-criar-usuario.sql (no FreeSQL
--          os privilégios são outros)
-- =============================================================================

COLUMN privilege    FORMAT A26
COLUMN granted_role FORMAT A24
COLUMN grantee      FORMAT A20
COLUMN owner        FORMAT A12
COLUMN table_name   FORMAT A20

-- 1. Privilégios de sistema recebidos diretamente.
-- Esperado: 11 linhas, as concedidas em 01-criar-usuario.sql:
--   CREATE JOB, CREATE MATERIALIZED VIEW, CREATE PROCEDURE, CREATE SEQUENCE,
--   CREATE SESSION, CREATE SYNONYM, CREATE TABLE, CREATE TRIGGER, CREATE TYPE,
--   CREATE VIEW, SELECT ANY DICTIONARY
SELECT privilege, admin_option FROM user_sys_privs ORDER BY privilege;

-- 2. Roles recebidas diretamente.
-- Esperado: SELECT_CATALOG_ROLE | default_role YES
SELECT granted_role, admin_option, default_role FROM user_role_privs ORDER BY granted_role;

-- Roles ativas agora, inclusive as que vêm dentro de outra role.
-- Esperado: SELECT_CATALOG_ROLE e as roles que ela inclui (por exemplo
--           HS_ADMIN_SELECT_ROLE; a lista exata varia com a versão)
SELECT role FROM session_roles ORDER BY role;

-- 3. O que a role concede: quantos privilégios de objeto, em quais tipos de objeto.
-- Esperado: milhares de SELECT em visões do dicionário (DBA_..., V_$...)
SELECT r.role, p.privilege, COUNT(*) AS objetos
  FROM session_roles r
  JOIN role_tab_privs p ON p.role = r.role
 GROUP BY r.role, p.privilege
 ORDER BY r.role, p.privilege;

-- 4. Privilégios de sistema efetivos (diretos + roles).
-- Esperado: os 11 diretos e o que vier das roles ativas
SELECT privilege FROM session_privs ORDER BY privilege;

-- Tenho este privilégio, e por onde ele veio?
-- Esperado: SELECT ANY DICTIONARY | direto
SELECT p.privilege,
       CASE
           WHEN EXISTS (SELECT 1 FROM user_sys_privs u WHERE u.privilege = p.privilege) THEN 'direto'
           ELSE 'por role'
       END AS origem
  FROM session_privs p
 WHERE p.privilege = 'SELECT ANY DICTIONARY';

-- 5. Cota em tablespace.
-- Esperado: USERS | max_bytes -1 (ilimitada) | bytes usados pelas tabelas e índices
SELECT tablespace_name, bytes, max_bytes FROM user_ts_quotas;

-- 6. Privilégios de objeto concedidos e recebidos.
CREATE TABLE tmp_publica (id NUMBER);
GRANT SELECT ON tmp_publica TO PUBLIC;

-- Esperado: PUBLIC | TMP_PUBLICA | SELECT | grantor ESTUDO
SELECT grantee, table_name, privilege, grantor FROM user_tab_privs_made ORDER BY table_name;

-- Recebidos (de outros donos, inclusive via PUBLIC).
-- Esperado: nenhuma linha recebida diretamente no ambiente de estudo
SELECT owner, table_name, privilege, grantor FROM user_tab_privs_recd ORDER BY owner, table_name;

REVOKE SELECT ON tmp_publica FROM PUBLIC;
DROP TABLE tmp_publica PURGE;

-- 7. Roteiro "por que não consigo acessar?", aplicado a uma visão do SYS.
-- 7a. Existe e eu vejo? (ALL_OBJECTS só mostra o que posso acessar)
-- Esperado: SYS | DBA_USERS | VIEW (visível graças à SELECT_CATALOG_ROLE)
SELECT owner, object_name, object_type FROM all_objects WHERE object_name = 'DBA_USERS' AND owner = 'SYS';

-- 7b. Por qual caminho tenho acesso?
-- Esperado: SELECT_CATALOG_ROLE | SELECT (via role). O segundo caminho é o privilégio
--           de sistema SELECT ANY DICTIONARY, recebido direto (passo 4): é ele que vale
--           dentro de procedures.
SELECT role, privilege FROM role_tab_privs WHERE owner = 'SYS' AND table_name = 'DBA_USERS';

-- Esperado: nenhuma linha (não há grant direto nem para PUBLIC nessa visão)
SELECT grantee, privilege FROM all_tab_privs WHERE table_schema = 'SYS' AND table_name = 'DBA_USERS';

-- 7c. O nome sem dono é resolvido por sinônimo público.
-- Esperado: PUBLIC | DBA_USERS | SYS | DBA_USERS
SELECT owner, synonym_name, table_owner, table_name FROM all_synonyms
 WHERE synonym_name = 'DBA_USERS' AND owner = 'PUBLIC';
