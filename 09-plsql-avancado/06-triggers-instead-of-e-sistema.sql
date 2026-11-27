-- =============================================================================
-- Tópico : Triggers INSTEAD OF e triggers de sistema (DDL, LOGON)
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE TRIGGER, CREATE VIEW
--          Passo 4 pede uma segunda conexão para conferir.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_pedidos AS SELECT * FROM pedidos;

-- 1. View de resumo: não é atualizável.
CREATE OR REPLACE VIEW tmp_vw_pedidos_resumo AS
SELECT p.id_pedido,
       c.nome AS cliente,
       p.status,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM tmp_pedidos p
  JOIN clientes c     ON c.id_cliente = p.id_cliente
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido, c.nome, p.status;

-- Esperado: ORA-01732 (operação de manipulação de dados não válida nesta view)
UPDATE tmp_vw_pedidos_resumo SET status = 'FATURADO' WHERE id_pedido = 1022;

-- 2. INSTEAD OF UPDATE: só o status pode mudar, e só para valores válidos.
CREATE OR REPLACE TRIGGER tmp_trg_vw_resumo_iou
    INSTEAD OF UPDATE ON tmp_vw_pedidos_resumo
    FOR EACH ROW
BEGIN
    IF :NEW.id_pedido <> :OLD.id_pedido
       OR :NEW.cliente <> :OLD.cliente
       OR :NEW.valor <> :OLD.valor
    THEN
        RAISE_APPLICATION_ERROR(-20301, 'Pela view só o status pode ser alterado');
    END IF;

    UPDATE tmp_pedidos SET status = :NEW.status WHERE id_pedido = :OLD.id_pedido;
END;
/

UPDATE tmp_vw_pedidos_resumo SET status = 'FATURADO' WHERE id_pedido = 1022;

-- Esperado: 1022 | Papelaria Central Ltda | FATURADO | 1513
SELECT * FROM tmp_vw_pedidos_resumo WHERE id_pedido = 1022;

-- Esperado: ORA-20301: Pela view só o status pode ser alterado
UPDATE tmp_vw_pedidos_resumo SET valor = 0 WHERE id_pedido = 1022;

-- 3. INSTEAD OF DELETE: excluir pela view vira cancelamento lógico.
CREATE OR REPLACE TRIGGER tmp_trg_vw_resumo_iod
    INSTEAD OF DELETE ON tmp_vw_pedidos_resumo
    FOR EACH ROW
BEGIN
    UPDATE tmp_pedidos SET status = 'CANCELADO' WHERE id_pedido = :OLD.id_pedido;
END;
/

DELETE FROM tmp_vw_pedidos_resumo WHERE id_pedido = 1023;

-- Esperado: 1023 | Fernanda Araujo | CANCELADO | 899 (a linha continua lá)
SELECT * FROM tmp_vw_pedidos_resumo WHERE id_pedido = 1023;

ROLLBACK;

-- 4. Trigger de DDL no schema: registrar mudanças de estrutura.
CREATE TABLE tmp_log_ddl (
    momento   TIMESTAMP DEFAULT SYSTIMESTAMP,
    usuario   VARCHAR2(128),
    evento    VARCHAR2(30),
    tipo      VARCHAR2(30),
    objeto    VARCHAR2(128)
);

CREATE OR REPLACE TRIGGER tmp_trg_log_ddl
    AFTER DDL ON SCHEMA
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO tmp_log_ddl (usuario, evento, tipo, objeto)
    VALUES (ORA_LOGIN_USER, ORA_SYSEVENT, ORA_DICT_OBJ_TYPE, ORA_DICT_OBJ_NAME);
    COMMIT;
END;
/

CREATE TABLE tmp_teste_ddl (id NUMBER);
ALTER TABLE tmp_teste_ddl ADD descricao VARCHAR2(50);
CREATE INDEX tmp_ix_teste_ddl ON tmp_teste_ddl (id);
DROP TABLE tmp_teste_ddl PURGE;

-- Esperado, em ordem:
--   CREATE TABLE TMP_TESTE_DDL
--   ALTER  TABLE TMP_TESTE_DDL
--   CREATE INDEX TMP_IX_TESTE_DDL
--   DROP   TABLE TMP_TESTE_DDL
SELECT evento, tipo, objeto FROM tmp_log_ddl ORDER BY momento;

DROP TRIGGER tmp_trg_log_ddl;

-- 5. BEFORE DROP: proteger um objeto específico.
CREATE TABLE tmp_protegida (id NUMBER);

CREATE OR REPLACE TRIGGER tmp_trg_protege_drop
    BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND ORA_DICT_OBJ_NAME = 'TMP_PROTEGIDA' THEN
        RAISE_APPLICATION_ERROR(-20302, 'A tabela TMP_PROTEGIDA não pode ser excluída');
    END IF;
END;
/

-- Esperado: erro com ORA-20302: A tabela TMP_PROTEGIDA não pode ser excluída
--           (acompanhado de ORA-00604 ou ORA-04088, conforme a versão)
DROP TABLE tmp_protegida PURGE;

-- Esperado: TMP_PROTEGIDA (continua existindo)
SELECT table_name FROM user_tables WHERE table_name = 'TMP_PROTEGIDA';

-- Para remover: primeiro o trigger, depois a tabela.
DROP TRIGGER tmp_trg_protege_drop;
DROP TABLE tmp_protegida PURGE;

-- 6. LOGON no schema: configurar a sessão de quem conecta como este usuário.
--    Corpo mínimo: um LOGON com erro impede o login.
CREATE OR REPLACE TRIGGER tmp_trg_logon
    AFTER LOGON ON SCHEMA
BEGIN
    DBMS_SESSION.SET_IDENTIFIER('estudo-logon-trigger');
    DBMS_APPLICATION_INFO.SET_MODULE('repositorio-oracle-plsql', 'logon');
END;
/

-- Em uma NOVA conexão como o mesmo usuário:
--   SELECT SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER') AS ident,
--          SYS_CONTEXT('USERENV', 'MODULE')            AS modulo
--     FROM dual;
--   Esperado: estudo-logon-trigger | repositorio-oracle-plsql
--
-- Nesta conexão, aberta antes do trigger, os valores continuam os de antes.

DROP TRIGGER tmp_trg_logon;

-- 7. Triggers de sistema no dicionário: base_object_type = SCHEMA ou DATABASE.
SELECT trigger_name, trigger_type, triggering_event, base_object_type, status
  FROM user_triggers
 WHERE base_object_type IN ('SCHEMA', 'DATABASE');
-- Esperado: nenhuma linha (todos os do script já foram removidos)

DROP TABLE tmp_log_ddl PURGE;
DROP VIEW tmp_vw_pedidos_resumo;
DROP TABLE tmp_pedidos PURGE;
