-- =============================================================================
-- Tópico : Triggers DML — BEFORE/AFTER, linha/instrução, :NEW/:OLD, WHEN,
--          predicados de evento, ordem de disparo, restrições
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE TRIGGER
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_pedidos  AS SELECT * FROM pedidos;
CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

CREATE TABLE tmp_hist_preco (
    id_produto   NUMBER(6),
    preco_antigo NUMBER(10,2),
    preco_novo   NUMBER(10,2),
    usuario      VARCHAR2(128) DEFAULT USER,
    momento      TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- 1. BEFORE INSERT de linha: normalizar e preencher valores.
CREATE OR REPLACE TRIGGER tmp_trg_pedidos_bi
    BEFORE INSERT ON tmp_pedidos
    FOR EACH ROW
BEGIN
    :NEW.status      := UPPER(NVL(:NEW.status, 'ABERTO'));
    :NEW.data_pedido := NVL(:NEW.data_pedido, SYSDATE);
    :NEW.observacao  := TRIM(:NEW.observacao);
END;
/

INSERT INTO tmp_pedidos (id_pedido, id_cliente, status, observacao)
VALUES (2001, 1, 'aberto', '   entregar pela manhã   ');

-- Esperado: 2001 | ABERTO | data preenchida: S | [entregar pela manhã]
SELECT id_pedido,
       status,
       CASE WHEN data_pedido IS NOT NULL THEN 'S' END AS data_preenchida,
       '[' || observacao || ']' AS observacao
  FROM tmp_pedidos
 WHERE id_pedido = 2001;

ROLLBACK;

-- 2. Histórico de preço: BEFORE UPDATE OF ... WHEN.
CREATE OR REPLACE TRIGGER tmp_trg_produtos_hist
    BEFORE UPDATE OF preco_unitario ON tmp_produtos
    FOR EACH ROW
    WHEN (NEW.preco_unitario <> OLD.preco_unitario)
BEGIN
    INSERT INTO tmp_hist_preco (id_produto, preco_antigo, preco_novo)
    VALUES (:OLD.id_produto, :OLD.preco_unitario, :NEW.preco_unitario);
END;
/

UPDATE tmp_produtos SET preco_unitario = ROUND(preco_unitario * 1.10, 2) WHERE id_categoria = 5;

-- "Atualizar" para o mesmo valor: o trigger dispara, mas o WHEN filtra.
UPDATE tmp_produtos SET preco_unitario = preco_unitario WHERE id_categoria = 2;

-- Esperado: 8 32.5 -> 35.75 | 9 45 -> 49.5 | 10 27.8 -> 30.58 (nada da categoria 2)
SELECT id_produto, preco_antigo, preco_novo FROM tmp_hist_preco ORDER BY id_produto;

ROLLBACK;

-- 3. Regra que constraint não expressa: redução de preço acima de 50%.
CREATE OR REPLACE TRIGGER tmp_trg_produtos_valida
    BEFORE UPDATE OF preco_unitario ON tmp_produtos
    FOR EACH ROW
    WHEN (NEW.preco_unitario < OLD.preco_unitario * 0.5)
BEGIN
    RAISE_APPLICATION_ERROR(-20201,
        'Produto ' || :OLD.id_produto || ': redução acima de 50% não permitida ('
        || :OLD.preco_unitario || ' -> ' || :NEW.preco_unitario || ')');
END;
/

-- Esperado: ORA-20201: Produto 3: redução acima de 50% não permitida (899 -> 399)
UPDATE tmp_produtos
   SET preco_unitario = CASE id_produto WHEN 3 THEN 399 ELSE preco_unitario * 0.9 END
 WHERE id_categoria = 2;

-- A instrução inteira foi desfeita, inclusive as linhas que passariam.
-- Esperado: 0 linhas no histórico; preços da categoria 2 inalterados (39.9, 89.9, 899, 249.9, 79.9)
SELECT COUNT(*) FROM tmp_hist_preco;
SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 2 ORDER BY id_produto;

DROP TRIGGER tmp_trg_produtos_valida;

-- 4. Trigger de instrução: dispara mesmo sem linha afetada.
CREATE OR REPLACE TRIGGER tmp_trg_produtos_aus
    AFTER UPDATE ON tmp_produtos
BEGIN
    DBMS_OUTPUT.PUT_LINE('[instrução UPDATE em tmp_produtos executada]');
END;
/

BEGIN
    UPDATE tmp_produtos SET preco_unitario = preco_unitario WHERE 1 = 0;
    DBMS_OUTPUT.PUT_LINE('Linhas: ' || SQL%ROWCOUNT);
END;
/
-- Esperado: [instrução UPDATE em tmp_produtos executada] | Linhas: 0

DROP TRIGGER tmp_trg_produtos_aus;

-- 5. Ordem de disparo.
CREATE TABLE tmp_ordem (id NUMBER, valor NUMBER);
INSERT INTO tmp_ordem VALUES (1, 10);
INSERT INTO tmp_ordem VALUES (2, 20);
COMMIT;

CREATE OR REPLACE TRIGGER tmp_trg_ordem_bs BEFORE UPDATE ON tmp_ordem
BEGIN
    DBMS_OUTPUT.PUT_LINE('BEFORE STATEMENT');
END;
/

CREATE OR REPLACE TRIGGER tmp_trg_ordem_br BEFORE UPDATE ON tmp_ordem FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE('  BEFORE ROW id ' || :OLD.id);
END;
/

CREATE OR REPLACE TRIGGER tmp_trg_ordem_ar AFTER UPDATE ON tmp_ordem FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE('  AFTER ROW  id ' || :OLD.id);
END;
/

CREATE OR REPLACE TRIGGER tmp_trg_ordem_as AFTER UPDATE ON tmp_ordem
BEGIN
    DBMS_OUTPUT.PUT_LINE('AFTER STATEMENT');
END;
/

BEGIN
    UPDATE tmp_ordem SET valor = valor + 1;
END;
/
-- Esperado (a ordem entre linhas 1 e 2 depende da leitura da tabela):
--   BEFORE STATEMENT
--     BEFORE ROW id 1
--     AFTER ROW  id 1
--     BEFORE ROW id 2
--     AFTER ROW  id 2
--   AFTER STATEMENT

ROLLBACK;

-- 6. Alterar :NEW em AFTER: erro de compilação.
CREATE OR REPLACE TRIGGER tmp_trg_ordem_errado AFTER UPDATE ON tmp_ordem FOR EACH ROW
BEGIN
    :NEW.valor := 0;
END;
/
-- Esperado: ORA-04084 (não é possível alterar valores NEW para este tipo de trigger),
--           apontado na criação do trigger.

-- Excluir a tabela exclui também os triggers dela.
DROP TABLE tmp_ordem PURGE;

-- 7. Trigger de vários eventos com INSERTING / UPDATING / DELETING.
CREATE TABLE tmp_auditoria (
    operacao  VARCHAR2(10),
    id_pedido NUMBER(8),
    detalhe   VARCHAR2(200)
);

CREATE OR REPLACE TRIGGER tmp_trg_pedidos_aud
    AFTER INSERT OR UPDATE OR DELETE ON tmp_pedidos
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO tmp_auditoria VALUES ('INSERT', :NEW.id_pedido, 'status ' || :NEW.status);
    ELSIF UPDATING('status') THEN
        INSERT INTO tmp_auditoria VALUES ('UPDATE', :NEW.id_pedido, :OLD.status || ' -> ' || :NEW.status);
    ELSIF UPDATING THEN
        INSERT INTO tmp_auditoria VALUES ('UPDATE', :NEW.id_pedido, 'outra coluna');
    ELSIF DELETING THEN
        INSERT INTO tmp_auditoria VALUES ('DELETE', :OLD.id_pedido, 'status ' || :OLD.status);
    END IF;
END;
/

INSERT INTO tmp_pedidos (id_pedido, id_cliente) VALUES (2002, 3);
UPDATE tmp_pedidos SET status = 'FATURADO' WHERE status = 'ABERTO' AND id_pedido < 2000;
UPDATE tmp_pedidos SET observacao = 'revisado' WHERE id_pedido = 1001;
DELETE FROM tmp_pedidos WHERE status = 'CANCELADO';

-- Esperado:
--   DELETE 1007 status CANCELADO
--   INSERT 2002 status ABERTO           (o trigger BEFORE do passo 1 preencheu o status)
--   UPDATE 1001 outra coluna
--   UPDATE 1022 ABERTO -> FATURADO
--   UPDATE 1023 ABERTO -> FATURADO
--   UPDATE 1024 ABERTO -> FATURADO
SELECT operacao, id_pedido, detalhe FROM tmp_auditoria ORDER BY operacao, id_pedido;

ROLLBACK;

-- 8. COMMIT dentro de trigger.
CREATE OR REPLACE TRIGGER tmp_trg_commit
    AFTER INSERT ON tmp_auditoria
BEGIN
    COMMIT;
END;
/

-- Esperado: ORA-04092 (não é possível COMMIT em um trigger), seguido de ORA-04088
INSERT INTO tmp_auditoria VALUES ('TESTE', 0, NULL);

DROP TRIGGER tmp_trg_commit;

-- 9. Triggers no dicionário; desabilitar e habilitar.
-- Esperado: TMP_TRG_PEDIDOS_AUD, TMP_TRG_PEDIDOS_BI, TMP_TRG_PRODUTOS_HIST, todos ENABLED
SELECT trigger_name, trigger_type, triggering_event, table_name, status
  FROM user_triggers
 WHERE trigger_name LIKE 'TMP_TRG%'
 ORDER BY trigger_name;

ALTER TABLE tmp_pedidos DISABLE ALL TRIGGERS;

INSERT INTO tmp_pedidos (id_pedido, id_cliente, data_pedido, status)
VALUES (2003, 1, SYSDATE, 'aberto');

-- Esperado: auditoria 0 | status aberto (minúsculo: o trigger que normaliza também não rodou)
SELECT (SELECT COUNT(*) FROM tmp_auditoria) AS auditoria, status
  FROM tmp_pedidos
 WHERE id_pedido = 2003;

ROLLBACK;
ALTER TABLE tmp_pedidos ENABLE ALL TRIGGERS;

DROP TABLE tmp_auditoria  PURGE;
DROP TABLE tmp_hist_preco PURGE;
DROP TABLE tmp_produtos   PURGE;
DROP TABLE tmp_pedidos    PURGE;
