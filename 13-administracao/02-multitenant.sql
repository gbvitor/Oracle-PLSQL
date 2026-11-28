-- =============================================================================
-- Tópico : Multitenant — em que container estou, que PDBs existem, usuários
--          comuns e locais
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : SELECT_CATALOG_ROLE (00-ambiente). Parte 2 [DBA], conectado no root.
-- =============================================================================

COLUMN name       FORMAT A20
COLUMN username   FORMAT A24
COLUMN con_name   FORMAT A16

-- -----------------------------------------------------------------------------
-- Parte 1: como o usuário de estudo, no PDB.
-- -----------------------------------------------------------------------------

-- Esperado: FREEPDB1 | 3 | YES (é um CDB)
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS con_name,
       SYS_CONTEXT('USERENV', 'CON_ID')   AS con_id,
       (SELECT cdb FROM v$database)       AS cdb
  FROM dual;

-- Dentro do PDB, V$PDBS mostra só o próprio PDB.
-- Esperado: FREEPDB1 | READ WRITE
SELECT con_id, name, open_mode, restricted FROM v$pdbs;

-- Usuários comuns (do CDB inteiro) e locais (só deste PDB).
-- Esperado: SYS, SYSTEM e outros do Oracle como COMMON = YES; ESTUDO como NO
SELECT username, common, oracle_maintained
  FROM dba_users
 WHERE username IN ('SYS', 'SYSTEM', 'ESTUDO') OR username LIKE 'C##%'
 ORDER BY common DESC, username;

-- Serviços deste container (o nome usado na string de conexão).
-- Esperado: freepdb1 (o serviço do PDB)
SELECT name, network_name FROM v$services ORDER BY name;

-- -----------------------------------------------------------------------------
-- Parte 2 [DBA]: conectado no CDB$ROOT (sqlplus / as sysdba no servidor, ou
-- sqlplus system@//localhost:1521/FREE).
-- -----------------------------------------------------------------------------

--   SHOW CON_NAME
--   Esperado: CDB$ROOT
--
--   SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;
--   Esperado: 2 PDB$SEED READ ONLY | 3 FREEPDB1 READ WRITE
--
--   Usuários por container, de uma vez (CDB_ = DBA_ de todos os containers):
--   SELECT con_id, COUNT(*) FROM cdb_users GROUP BY con_id ORDER BY con_id;
--
--   Trocar de container sem reconectar:
--   ALTER SESSION SET CONTAINER = FREEPDB1;
--   SHOW CON_NAME
--   Esperado: FREEPDB1
--
--   Garantir que o PDB abre sozinho quando a instância sobe:
--   ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;
--
--   Usuário comum precisa do prefixo C##:
--   CREATE USER admin_teste IDENTIFIED BY "Senha#2026";
--   Esperado no root: ORA-65096 (nome de usuário ou role comum inválido)
