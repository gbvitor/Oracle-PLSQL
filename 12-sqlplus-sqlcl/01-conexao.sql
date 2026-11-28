-- =============================================================================
-- Tópico : Conexão — conferir onde e como se está conectado
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus ou SQLcl)
-- Requer : conexão como o usuário de estudo
--
-- Conectar é feito antes do script (sqlplus estudo@//localhost:1521/FREEPDB1).
-- Aqui ficam os comandos para confirmar a sessão e o COMMIT implícito do CONNECT.
-- =============================================================================

-- 1. Quem e onde.
SHOW USER
-- Esperado: USER is "ESTUDO"

SHOW CON_NAME
-- Esperado: FREEPDB1 (no container Free)

-- Esperado: ESTUDO | FREEPDB1 | nome do serviço | máquina do cliente | programa (sqlplus...)
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER')   AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME')       AS container,
       SYS_CONTEXT('USERENV', 'SERVICE_NAME')   AS servico,
       SYS_CONTEXT('USERENV', 'HOST')           AS maquina_cliente,
       SYS_CONTEXT('USERENV', 'MODULE')         AS programa
  FROM dual;

-- Endereço do servidor e protocolo da conexão.
-- Esperado: endereço IP do servidor e tcp
SELECT SYS_CONTEXT('USERENV', 'SERVER_HOST') AS servidor,
       SYS_CONTEXT('USERENV', 'NETWORK_PROTOCOL') AS protocolo
  FROM dual;

-- 2. O COMMIT implícito do CONNECT.
CREATE TABLE tmp_conexao (id NUMBER);

INSERT INTO tmp_conexao VALUES (1);

-- Reconectar como o mesmo usuário (o SQL*Plus pede a senha):
--   CONNECT estudo@//localhost:1521/FREEPDB1
--
-- Depois de reconectar:
--   SELECT COUNT(*) FROM tmp_conexao;
--   Esperado: 1. O INSERT, que nunca recebeu COMMIT, foi confirmado pelo CONNECT.

-- Sem reconectar, desfazer e limpar:
ROLLBACK;
DROP TABLE tmp_conexao PURGE;

-- 3. EXIT confirma por padrão; para sair desfazendo:
--   EXIT ROLLBACK
-- ou, para todas as saídas da sessão:
SET EXITCOMMIT OFF
SET EXITCOMMIT ON
