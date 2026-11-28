-- =============================================================================
-- Tópico : Auditoria unificada — modo, políticas prontas, política com condição,
--          consulta da trilha, FGA, limpeza
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : Partes 1 e 3 com AUDIT_ADMIN (ou como DBA) no PDB; Parte 2 como o
--          usuário de estudo. Não funciona no FreeSQL.
-- =============================================================================

SET LINESIZE 220
COLUMN policy_name  FORMAT A28
COLUMN entity_name  FORMAT A14
COLUMN dbusername   FORMAT A12
COLUMN action_name  FORMAT A10
COLUMN object_name  FORMAT A14
COLUMN sql_text     FORMAT A50 TRUNCATED
COLUMN module       FORMAT A16

-- -----------------------------------------------------------------------------
-- Parte 1 [AUDIT_ADMIN]: situação atual e uma política nova.
-- -----------------------------------------------------------------------------

-- Modo: TRUE = unificado puro; FALSE = misto (o padrão do 19c).
SELECT parameter, value FROM v$option WHERE parameter = 'Unified Auditing';

-- Políticas ativas.
-- Esperado: ORA_SECURECONFIG e ORA_LOGON_FAILURES, para todos os usuários
SELECT policy_name, enabled_option, entity_name, success, failure
  FROM audit_unified_enabled_policies
 ORDER BY policy_name;

-- Auditar UPDATE e DELETE em CLIENTES feitos fora da "aplicação" (módulo diferente).
-- O NVL evita que sessão sem módulo escape: NULL <> 'x' não é verdadeiro.
CREATE AUDIT POLICY tmp_pol_clientes
    ACTIONS UPDATE ON estudo.clientes, DELETE ON estudo.clientes
    WHEN 'NVL(SYS_CONTEXT(''USERENV'', ''MODULE''), ''-'') <> ''tmp_app_vendas'''
    EVALUATE PER STATEMENT;

AUDIT POLICY tmp_pol_clientes;

-- Esperado: TMP_POL_CLIENTES com ação UPDATE e DELETE no objeto CLIENTES
SELECT policy_name, audit_option, object_schema, object_name, condition_eval_opt
  FROM audit_unified_policies
 WHERE policy_name = 'TMP_POL_CLIENTES';

-- FGA: registrar consultas que leem o limite de crédito de clientes acima de 50 mil.
BEGIN
    DBMS_FGA.ADD_POLICY(
        object_schema   => 'ESTUDO',
        object_name     => 'CLIENTES',
        policy_name     => 'TMP_FGA_LIMITE',
        audit_condition => 'limite_credito > 50000',
        audit_column    => 'LIMITE_CREDITO',
        statement_types => 'SELECT');
END;
/

-- -----------------------------------------------------------------------------
-- Parte 2 [ESTUDO]: gerar eventos (em outra sessão, conectada como estudo).
-- -----------------------------------------------------------------------------
--   Como "aplicação": não deve ser auditado.
--     EXEC DBMS_APPLICATION_INFO.SET_MODULE('tmp_app_vendas', NULL)
--     UPDATE clientes SET limite_credito = limite_credito WHERE id_cliente = 1;
--     ROLLBACK;
--
--   Fora da aplicação: deve ser auditado.
--     EXEC DBMS_APPLICATION_INFO.SET_MODULE('sqlplus manual', NULL)
--     UPDATE clientes SET limite_credito = limite_credito WHERE id_cliente = 2;
--     ROLLBACK;
--
--   Leitura do limite de clientes grandes (FGA):
--     SELECT nome, limite_credito FROM clientes WHERE id_cliente = 10;
--     (limite 100000: atende à condição)
--     SELECT nome, limite_credito FROM clientes WHERE id_cliente = 4;
--     (limite 5000: não atende, não é registrado)
--
--   Uma tentativa de login com senha errada (ORA_LOGON_FAILURES):
--     CONNECT estudo/senha_errada@//localhost:1521/FREEPDB1

-- -----------------------------------------------------------------------------
-- Parte 3 [AUDIT_ADMIN]: a trilha.
-- -----------------------------------------------------------------------------

-- Em 19c os registros podem ficar numa fila em memória por alguns segundos.
EXEC DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL

-- Esperado:
--   UPDATE em CLIENTES pelo módulo "sqlplus manual" (política TMP_POL_CLIENTES);
--     o UPDATE do módulo tmp_app_vendas não aparece
--   SELECT em CLIENTES (política TMP_FGA_LIMITE) só para o cliente 10
--   LOGON com return_code 1017 (ORA_LOGON_FAILURES)
SELECT event_timestamp, dbusername, action_name, object_name, return_code,
       unified_audit_policies, fga_policy_name, sql_text
  FROM unified_audit_trail
 WHERE event_timestamp > SYSTIMESTAMP - INTERVAL '30' MINUTE
   AND (unified_audit_policies LIKE '%TMP_POL_CLIENTES%'
        OR fga_policy_name = 'TMP_FGA_LIMITE'
        OR (action_name = 'LOGON' AND return_code <> 0))
 ORDER BY event_timestamp;

-- Volume da trilha (planejar retenção e limpeza).
SELECT TRUNC(event_timestamp) AS dia, COUNT(*) AS registros
  FROM unified_audit_trail
 WHERE event_timestamp > SYSTIMESTAMP - INTERVAL '7' DAY
 GROUP BY TRUNC(event_timestamp)
 ORDER BY dia;

-- Limpeza dos exemplos.
NOAUDIT POLICY tmp_pol_clientes;
DROP AUDIT POLICY tmp_pol_clientes;

BEGIN
    DBMS_FGA.DROP_POLICY(object_schema => 'ESTUDO', object_name => 'CLIENTES', policy_name => 'TMP_FGA_LIMITE');
END;
/

-- Limpeza da trilha (em produção, com política de retenção definida):
--   BEGIN
--       DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
--           audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
--           last_archive_time => SYSTIMESTAMP - INTERVAL '90' DAY);
--       DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
--           audit_trail_type        => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
--           use_last_arch_timestamp => TRUE);
--   END;
--   /
