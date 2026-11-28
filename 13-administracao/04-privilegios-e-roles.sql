-- =============================================================================
-- Tópico : Privilégios e roles — grant de objeto, role, READ contra SELECT,
--          revogação em cascata (GRANT OPTION) e sem cascata (ADMIN OPTION)
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : Parte 1 [DBA] no PDB; Partes 2 e 3 em sessões dos usuários indicados.
--          Os usuários de teste são criados e removidos pelo próprio script.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Parte 1 [DBA]: usuários de teste e uma role.
-- -----------------------------------------------------------------------------
CREATE USER tmp_ana   IDENTIFIED BY "Ana#2026";
CREATE USER tmp_bruno IDENTIFIED BY "Bruno#2026";
CREATE USER tmp_carla IDENTIFIED BY "Carla#2026";
GRANT CREATE SESSION TO tmp_ana, tmp_bruno, tmp_carla;

CREATE ROLE tmp_role_leitura_vendas;

-- -----------------------------------------------------------------------------
-- Parte 2 [ESTUDO]: o dono concede.
-- -----------------------------------------------------------------------------

-- Leitura sem trava para relatório.
GRANT READ ON clientes TO tmp_role_leitura_vendas;
GRANT READ ON pedidos  TO tmp_role_leitura_vendas;

-- SELECT com direito de repassar, para a Ana.
GRANT SELECT ON produtos TO tmp_ana WITH GRANT OPTION;

-- Esperado: TMP_ROLE_LEITURA_VENDAS READ em CLIENTES e PEDIDOS | TMP_ANA SELECT em PRODUTOS, grantable YES
SELECT grantee, table_name, privilege, grantable
  FROM user_tab_privs_made
 WHERE grantee LIKE 'TMP%'
 ORDER BY grantee, table_name;

-- -----------------------------------------------------------------------------
-- Parte 1 [DBA], continuação: a role vai para o Bruno.
-- -----------------------------------------------------------------------------
GRANT tmp_role_leitura_vendas TO tmp_bruno;

-- -----------------------------------------------------------------------------
-- Parte 3: sessões dos usuários de teste.
-- -----------------------------------------------------------------------------

-- [TMP_BRUNO] READ permite consultar...
--   SELECT COUNT(*) FROM estudo.clientes;
--   Esperado: 12
-- ...mas não travar linhas:
--   SELECT * FROM estudo.clientes WHERE id_cliente = 1 FOR UPDATE;
--   Esperado: ORA-01031 (privilégios insuficientes)
-- e não alcança tabela fora da role:
--   SELECT COUNT(*) FROM estudo.produtos;
--   Esperado: ORA-00942

-- [TMP_ANA] repassa o SELECT para a Carla:
--   GRANT SELECT ON estudo.produtos TO tmp_carla;
--
-- [TMP_CARLA]
--   SELECT COUNT(*) FROM estudo.produtos;
--   Esperado: 15

-- -----------------------------------------------------------------------------
-- Parte 2 [ESTUDO], continuação: revogar da Ana derruba o que ela concedeu.
-- -----------------------------------------------------------------------------

-- Esperado: duas linhas: TMP_ANA (grantor ESTUDO) e TMP_CARLA (grantor TMP_ANA)
SELECT grantee, grantor, privilege FROM all_tab_privs WHERE table_schema = USER AND table_name = 'PRODUTOS';

REVOKE SELECT ON produtos FROM tmp_ana;

-- Esperado: nenhuma linha. A Carla perdeu o acesso junto (cascata do GRANT OPTION).
SELECT grantee, grantor, privilege FROM all_tab_privs WHERE table_schema = USER AND table_name = 'PRODUTOS';

-- -----------------------------------------------------------------------------
-- Parte 1 [DBA], continuação: ADMIN OPTION não cascateia.
-- -----------------------------------------------------------------------------
GRANT CREATE TABLE TO tmp_ana WITH ADMIN OPTION;

-- [TMP_ANA]
--   GRANT CREATE TABLE TO tmp_carla;

REVOKE CREATE TABLE FROM tmp_ana;

-- Esperado: TMP_CARLA continua com CREATE TABLE (privilégio de sistema não cai em cascata)
SELECT grantee, privilege FROM dba_sys_privs WHERE grantee IN ('TMP_ANA', 'TMP_CARLA') ORDER BY grantee;

-- Grants para PUBLIC em objetos que não são do Oracle (auditoria rápida).
-- Esperado: nenhuma linha no ambiente de estudo
SELECT owner, table_name, privilege
  FROM dba_tab_privs
 WHERE grantee = 'PUBLIC'
   AND owner IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')
 ORDER BY owner, table_name;

-- Limpeza [DBA].
DROP USER tmp_carla CASCADE;
DROP USER tmp_bruno CASCADE;
DROP USER tmp_ana   CASCADE;
DROP ROLE tmp_role_leitura_vendas;
