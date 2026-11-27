-- =============================================================================
-- Tópico : Constraints — PK, UK, FK (CASCADE, SET NULL), CHECK, NOT NULL
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : usuário com CREATE TABLE
-- =============================================================================

-- 1. Tabelas de teste com todos os tipos, nomeados.
CREATE TABLE tmp_contratos (
    id_contrato   NUMBER        CONSTRAINT pk_tmp_contratos PRIMARY KEY,
    numero        VARCHAR2(20)  CONSTRAINT nn_tmp_contratos_numero NOT NULL,
    data_inicio   DATE          NOT NULL,
    data_fim      DATE,
    valor         NUMBER(12,2),
    CONSTRAINT uk_tmp_contratos_numero UNIQUE (numero),
    CONSTRAINT ck_tmp_contratos_valor  CHECK (valor >= 0),
    CONSTRAINT ck_tmp_contratos_datas  CHECK (data_fim >= data_inicio)
);

CREATE TABLE tmp_parcelas (
    id_contrato  NUMBER  NOT NULL,
    nr_parcela   NUMBER  NOT NULL,
    valor        NUMBER(12,2),
    CONSTRAINT pk_tmp_parcelas PRIMARY KEY (id_contrato, nr_parcela),
    CONSTRAINT fk_tmp_parcelas_contrato FOREIGN KEY (id_contrato)
        REFERENCES tmp_contratos (id_contrato) ON DELETE CASCADE
);

CREATE TABLE tmp_anexos (
    id_anexo     NUMBER PRIMARY KEY,
    id_contrato  NUMBER,
    CONSTRAINT fk_tmp_anexos_contrato FOREIGN KEY (id_contrato)
        REFERENCES tmp_contratos (id_contrato) ON DELETE SET NULL
);

-- Índices para as FKs (o Oracle não cria sozinho).
-- A PK de tmp_parcelas começa por id_contrato e já serve de índice da FK.
CREATE INDEX tmp_ix_anexos_contrato ON tmp_anexos (id_contrato);

-- 2. As constraints no dicionário.
-- Esperado: o NOT NULL de data_inicio aparece com nome SYS_C...
SELECT table_name, constraint_name, constraint_type, search_condition_vc AS condicao, delete_rule
  FROM user_constraints
 WHERE table_name IN ('TMP_CONTRATOS', 'TMP_PARCELAS', 'TMP_ANEXOS')
 ORDER BY table_name, constraint_type, constraint_name;

-- Índices criados para PK e UK.
-- Esperado: PK_TMP_CONTRATOS, UK_TMP_CONTRATOS_NUMERO, PK_TMP_PARCELAS, SYS_C... (PK de anexos)
SELECT table_name, index_name, uniqueness
  FROM user_indexes
 WHERE table_name IN ('TMP_CONTRATOS', 'TMP_PARCELAS', 'TMP_ANEXOS')
 ORDER BY table_name, index_name;

-- 3. Dados válidos.
INSERT INTO tmp_contratos VALUES (1, 'CT-001', DATE '2026-01-01', DATE '2026-12-31', 12000);
INSERT INTO tmp_contratos VALUES (2, 'CT-002', DATE '2026-03-01', NULL,              NULL);
INSERT INTO tmp_parcelas  VALUES (1, 1, 1000);
INSERT INTO tmp_parcelas  VALUES (1, 2, 1000);
INSERT INTO tmp_anexos    VALUES (10, 1);
COMMIT;

-- 4. Cada constraint recusando um dado inválido.
-- Esperado: ORA-00001 (UK_TMP_CONTRATOS_NUMERO)
INSERT INTO tmp_contratos VALUES (3, 'CT-001', DATE '2026-01-01', NULL, 0);

-- Esperado: ORA-02290 (CK_TMP_CONTRATOS_VALOR)
INSERT INTO tmp_contratos VALUES (3, 'CT-003', DATE '2026-01-01', NULL, -1);

-- Esperado: ORA-02290 (CK_TMP_CONTRATOS_DATAS)
INSERT INTO tmp_contratos VALUES (3, 'CT-003', DATE '2026-06-01', DATE '2026-01-01', 0);

-- Esperado: ORA-01400 (não é possível inserir NULL em NUMERO)
INSERT INTO tmp_contratos VALUES (3, NULL, DATE '2026-01-01', NULL, 0);

-- Esperado: ORA-02291 (FK_TMP_PARCELAS_CONTRATO: chave mãe não localizada)
INSERT INTO tmp_parcelas VALUES (99, 1, 100);

-- 5. CHECK aceita UNKNOWN: o contrato 2 tem valor e data_fim nulos e passou.
-- Esperado: 1 linha (contrato 2)
SELECT id_contrato, valor, data_fim FROM tmp_contratos WHERE valor IS NULL;

-- 6. CHECK não aceita SYSDATE nem subquery.
-- Esperado: ORA-02436 (a especificação de data ou sistema está incorreta na restrição CHECK)
ALTER TABLE tmp_contratos ADD CONSTRAINT ck_tmp_contratos_futuro CHECK (data_inicio <= SYSDATE);

-- 7. ON DELETE CASCADE e ON DELETE SET NULL.
DELETE FROM tmp_contratos WHERE id_contrato = 1;

-- Esperado: 0 parcelas (apagadas em cascata) | anexo 10 com id_contrato nulo
SELECT (SELECT COUNT(*) FROM tmp_parcelas)                  AS parcelas,
       (SELECT id_contrato FROM tmp_anexos WHERE id_anexo = 10) AS contrato_do_anexo
  FROM dual;

ROLLBACK;

-- 8. Renomear a constraint gerada pelo sistema.
DECLARE
    v_nome user_constraints.constraint_name%TYPE;
BEGIN
    SELECT constraint_name INTO v_nome
      FROM user_constraints
     WHERE table_name = 'TMP_ANEXOS' AND constraint_type = 'P';
    EXECUTE IMMEDIATE 'ALTER TABLE tmp_anexos RENAME CONSTRAINT ' || v_nome || ' TO pk_tmp_anexos';
END;
/

-- Esperado: PK_TMP_ANEXOS
SELECT constraint_name FROM user_constraints WHERE table_name = 'TMP_ANEXOS' AND constraint_type = 'P';

-- 9. Apagar a tabela pai com FKs apontando para ela.
-- Esperado: ORA-02449 (chaves exclusivas/primárias na tabela referenciadas por chaves externas)
DROP TABLE tmp_contratos;

-- Limpeza
DROP TABLE tmp_anexos PURGE;
DROP TABLE tmp_parcelas PURGE;
DROP TABLE tmp_contratos PURGE;
