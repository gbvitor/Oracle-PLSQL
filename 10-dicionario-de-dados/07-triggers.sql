-- =============================================================================
-- Tópico : Triggers no dicionário — USER_TRIGGERS, USER_TRIGGER_COLS,
--          corpo, pesquisa de texto e DBMS_METADATA
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE TRIGGER
-- =============================================================================

COLUMN trigger_name     FORMAT A26
COLUMN trigger_type     FORMAT A16
COLUMN triggering_event FORMAT A26
COLUMN when_clause      FORMAT A40
COLUMN texto            FORMAT A60

-- Objetos de exemplo.
CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

CREATE TABLE tmp_hist_preco (
    id_produto   NUMBER(6),
    preco_antigo NUMBER(10,2),
    preco_novo   NUMBER(10,2),
    momento      TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE OR REPLACE TRIGGER tmp_trg_produtos_hist
    BEFORE UPDATE OF preco_unitario ON tmp_produtos
    FOR EACH ROW
    WHEN (NEW.preco_unitario <> OLD.preco_unitario)
BEGIN
    INSERT INTO tmp_hist_preco (id_produto, preco_antigo, preco_novo)
    VALUES (:OLD.id_produto, :OLD.preco_unitario, :NEW.preco_unitario);
END;
/

CREATE OR REPLACE TRIGGER tmp_trg_produtos_nome
    BEFORE INSERT OR UPDATE ON tmp_produtos
    FOR EACH ROW
BEGIN
    :NEW.nome := TRIM(:NEW.nome);
END;
/

CREATE OR REPLACE TRIGGER tmp_trg_produtos_aviso
    AFTER DELETE ON tmp_produtos
BEGIN
    RAISE_APPLICATION_ERROR(-20401, 'Exclusão de produto não permitida');
END;
/

ALTER TRIGGER tmp_trg_produtos_aviso DISABLE;

-- 1. Triggers de uma tabela.
-- Esperado:
--   TMP_TRG_PRODUTOS_AVISO AFTER STATEMENT  DELETE           DISABLED
--   TMP_TRG_PRODUTOS_HIST  BEFORE EACH ROW  UPDATE           ENABLED  NEW.preco_unitario <> OLD.preco_unitario
--   TMP_TRG_PRODUTOS_NOME  BEFORE EACH ROW  INSERT OR UPDATE ENABLED
SELECT trigger_name, trigger_type, triggering_event, status, when_clause
  FROM user_triggers
 WHERE table_name = 'TMP_PRODUTOS'
 ORDER BY trigger_name;

-- 2. Tabelas com triggers e quantos estão desligados.
-- Esperado: TMP_PRODUTOS | 3 | 1
SELECT table_name,
       COUNT(*) AS triggers,
       SUM(CASE WHEN status = 'DISABLED' THEN 1 ELSE 0 END) AS desligados
  FROM user_triggers
 WHERE base_object_type = 'TABLE'
 GROUP BY table_name
 ORDER BY table_name;

-- 3. Triggers de schema e de banco (afetam todo DDL ou todo login).
-- Esperado: nenhuma linha no ambiente de estudo
SELECT trigger_name, trigger_type, triggering_event, base_object_type, status
  FROM user_triggers
 WHERE base_object_type IN ('SCHEMA', 'DATABASE');

-- 4. Colunas citadas pelo trigger.
-- Esperado (TMP_TRG_PRODUTOS_HIST): ID_PRODUTO (OLD) e PRECO_UNITARIO (OLD, NEW, e no UPDATE OF)
SELECT column_name, column_list, column_usage
  FROM user_trigger_cols
 WHERE trigger_name = 'TMP_TRG_PRODUTOS_HIST'
 ORDER BY column_name;

-- 5. O cabeçalho e o corpo.
SET LONG 10000
-- Esperado: description = "tmp_trg_produtos_hist BEFORE UPDATE OF preco_unitario ON tmp_produtos FOR EACH ROW"
--           trigger_body = o bloco BEGIN ... END;
SELECT description, trigger_body FROM user_triggers WHERE trigger_name = 'TMP_TRG_PRODUTOS_HIST';

-- 6. Pesquisar no código dos triggers: quem grava em TMP_HIST_PRECO?
-- Esperado: TMP_TRG_PRODUTOS_HIST | INSERT INTO tmp_hist_preco ...
--           (o código guardado começa no cabeçalho "TRIGGER ...": a linha deve ser 6)
SELECT name, line, TRIM(text) AS texto
  FROM user_source
 WHERE type = 'TRIGGER'
   AND UPPER(text) LIKE '%TMP_HIST_PRECO%'
 ORDER BY name, line;

-- 7. DDL completo, com o estado do trigger.
SET PAGESIZE 0
SELECT DBMS_METADATA.GET_DDL('TRIGGER', 'TMP_TRG_PRODUTOS_AVISO') AS ddl FROM dual;
SET PAGESIZE 14
-- Esperado: CREATE OR REPLACE EDITIONABLE TRIGGER ... seguido de
--           ALTER TRIGGER "ESTUDO"."TMP_TRG_PRODUTOS_AVISO" DISABLE

-- Excluir a tabela exclui os triggers dela.
DROP TABLE tmp_produtos PURGE;
DROP TABLE tmp_hist_preco PURGE;

-- Esperado: nenhuma linha
SELECT trigger_name FROM user_triggers WHERE trigger_name LIKE 'TMP_TRG_PRODUTOS%';
