-- =============================================================================
-- Tópico : Usuários, perfis e senhas
-- Seção  : 13-administracao
-- Versão : 19c (NO AUTHENTICATION exige 18c+)
-- Requer : Parte 1 como o usuário de estudo; Parte 2 [DBA] no PDB
--          (sqlplus system@//localhost:1521/FREEPDB1)
-- =============================================================================

COLUMN username       FORMAT A20
COLUMN account_status FORMAT A18
COLUMN profile        FORMAT A20
COLUMN resource_name  FORMAT A28
COLUMN limit          FORMAT A20

-- -----------------------------------------------------------------------------
-- Parte 1: o próprio usuário.
-- -----------------------------------------------------------------------------

-- Esperado: ESTUDO | OPEN | USERS | TEMP | data de vencimento da senha (ou vazio)
SELECT username, account_status, default_tablespace, temporary_tablespace, expiry_date, created
  FROM user_users;

-- Regras de senha do meu perfil.
-- Esperado: FAILED_LOGIN_ATTEMPTS 10, PASSWORD_LIFE_TIME 180, PASSWORD_LOCK_TIME 1 ...
--           (valores do perfil DEFAULT; o ambiente pode ter outros)
SELECT resource_name, limit FROM user_password_limits ORDER BY resource_name;

-- Limites de recurso.
SELECT resource_name, limit FROM user_resource_limits ORDER BY resource_name;

-- -----------------------------------------------------------------------------
-- Parte 2 [DBA]: perfil, usuário, bloqueio por senha errada, schema sem login.
-- -----------------------------------------------------------------------------

-- Perfil para contas técnicas de teste.
CREATE PROFILE tmp_perfil_estudo LIMIT
    FAILED_LOGIN_ATTEMPTS 3
    PASSWORD_LOCK_TIME    1/1440
    PASSWORD_LIFE_TIME    UNLIMITED
    SESSIONS_PER_USER     2;

CREATE USER tmp_usuario IDENTIFIED BY "Teste#2026"
    DEFAULT TABLESPACE users
    QUOTA 10M ON users
    PROFILE tmp_perfil_estudo;

GRANT CREATE SESSION TO tmp_usuario;

-- Esperado: TMP_USUARIO | OPEN | TMP_PERFIL_ESTUDO
SELECT username, account_status, profile, lock_date FROM dba_users WHERE username = 'TMP_USUARIO';

-- Em outro terminal, errar a senha três vezes:
--   sqlplus tmp_usuario/errada@//localhost:1521/FREEPDB1   (três vezes: ORA-01017)
--   na quarta, mesmo com a senha certa: ORA-28000 (a conta está bloqueada)

-- Esperado depois das três tentativas: LOCKED(TIMED), com lock_date preenchido.
--           Depois de 1 minuto (PASSWORD_LOCK_TIME 1/1440), a conta libera sozinha.
SELECT username, account_status, lock_date FROM dba_users WHERE username = 'TMP_USUARIO';

-- Desbloquear na hora.
ALTER USER tmp_usuario ACCOUNT UNLOCK;

-- Forçar troca de senha no próximo login.
ALTER USER tmp_usuario PASSWORD EXPIRE;
-- Esperado: EXPIRED; no login, o SQL*Plus pede a senha nova (ORA-28001)
SELECT username, account_status FROM dba_users WHERE username = 'TMP_USUARIO';

-- Schema que não aceita login [18c+].
CREATE USER tmp_schema_dados NO AUTHENTICATION;

-- Esperado: TMP_SCHEMA_DADOS | authentication_type NONE
SELECT username, authentication_type, account_status FROM dba_users WHERE username = 'TMP_SCHEMA_DADOS';

-- Contas que costumam dar problema: vencidas, bloqueadas, vencendo em 15 dias.
SELECT username, account_status, expiry_date, profile
  FROM dba_users
 WHERE oracle_maintained = 'N'
   AND (account_status <> 'OPEN' OR expiry_date < SYSDATE + 15)
 ORDER BY expiry_date;

-- Limpeza.
DROP USER tmp_schema_dados CASCADE;
DROP USER tmp_usuario CASCADE;
DROP PROFILE tmp_perfil_estudo;
