-- =============================================================================
-- Tópico : Estados de constraint — DISABLE, NOVALIDATE, DEFERRABLE
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : usuário com CREATE TABLE
-- =============================================================================

CREATE TABLE tmp_valores (id NUMBER PRIMARY KEY, valor NUMBER);
INSERT INTO tmp_valores VALUES (1, 10);
INSERT INTO tmp_valores VALUES (2, -5);
INSERT INTO tmp_valores VALUES (3, 20);
COMMIT;

-- 1. Criar a regra com dados ruins já gravados: o padrão (VALIDATE) falha.
-- Esperado: ORA-02293 (não é possível validar (...) - restrição de verificação violada)
ALTER TABLE tmp_valores ADD CONSTRAINT ck_tmp_valores CHECK (valor >= 0);

-- 2. ENABLE NOVALIDATE: vale daqui para frente; o -5 antigo continua lá.
ALTER TABLE tmp_valores ADD CONSTRAINT ck_tmp_valores CHECK (valor >= 0) ENABLE NOVALIDATE;

-- Esperado: ORA-02290 para dado novo inválido
INSERT INTO tmp_valores VALUES (4, -1);

-- Esperado: ENABLED | NOT VALIDATED
SELECT constraint_name, status, validated
  FROM user_constraints
 WHERE constraint_name = 'CK_TMP_VALORES';

-- 3. Encontrar as linhas que impedem a validação.
-- Esperado: id 2
SELECT * FROM tmp_valores WHERE NOT (valor >= 0);

-- Com a tabela de exceções.
CREATE TABLE tmp_exceptions (
    row_id      ROWID,
    owner       VARCHAR2(128),
    table_name  VARCHAR2(128),
    constraint  VARCHAR2(128)
);

-- Esperado: ORA-02293 (o comando falha, mas registra as linhas)
ALTER TABLE tmp_valores ENABLE VALIDATE CONSTRAINT ck_tmp_valores EXCEPTIONS INTO tmp_exceptions;

-- Esperado: id 2
SELECT v.*
  FROM tmp_valores    v
  JOIN tmp_exceptions e ON e.row_id = v.ROWID;

-- Corrigir e validar.
UPDATE tmp_valores SET valor = 0 WHERE id = 2;
COMMIT;

ALTER TABLE tmp_valores ENABLE VALIDATE CONSTRAINT ck_tmp_valores;

-- Esperado: ENABLED | VALIDATED
SELECT constraint_name, status, validated
  FROM user_constraints
 WHERE constraint_name = 'CK_TMP_VALORES';

-- 4. DISABLE para carga e reabilitação depois.
ALTER TABLE tmp_valores DISABLE CONSTRAINT ck_tmp_valores;

-- Esperado: aceito (constraint desligada)
INSERT INTO tmp_valores VALUES (5, -100);
COMMIT;

-- Esperado: ORA-02293 ao religar com validação
ALTER TABLE tmp_valores ENABLE CONSTRAINT ck_tmp_valores;

DELETE FROM tmp_valores WHERE id = 5;
COMMIT;
ALTER TABLE tmp_valores ENABLE CONSTRAINT ck_tmp_valores;

-- 5. DEFERRABLE: trocar duas chaves únicas de lugar.
CREATE TABLE tmp_posicoes (
    item     VARCHAR2(10) PRIMARY KEY,
    posicao  NUMBER,
    CONSTRAINT uk_tmp_posicoes UNIQUE (posicao) DEFERRABLE INITIALLY IMMEDIATE
);
INSERT INTO tmp_posicoes VALUES ('A', 1);
INSERT INTO tmp_posicoes VALUES ('B', 2);
COMMIT;

-- Verificação imediata: o primeiro UPDATE já viola (duas linhas com posição 2).
-- Esperado: ORA-00001
UPDATE tmp_posicoes SET posicao = 2 WHERE item = 'A';

-- Adiando para o COMMIT: o estado intermediário é tolerado.
SET CONSTRAINT uk_tmp_posicoes DEFERRED;

UPDATE tmp_posicoes SET posicao = 2 WHERE item = 'A';
UPDATE tmp_posicoes SET posicao = 1 WHERE item = 'B';
COMMIT;

-- Esperado: A 2 | B 1
SELECT * FROM tmp_posicoes ORDER BY item;

-- 6. Se no COMMIT a regra continuar violada, a transação inteira é desfeita.
SET CONSTRAINT uk_tmp_posicoes DEFERRED;

UPDATE tmp_posicoes SET posicao = 1 WHERE item = 'A';

-- Esperado: ORA-02091 (transação revertida) seguido de ORA-00001
COMMIT;

-- Esperado: A 2 | B 1 (nada mudou)
SELECT * FROM tmp_posicoes ORDER BY item;

-- 7. A UK adiável usa índice não único.
-- Esperado: NONUNIQUE
SELECT index_name, uniqueness FROM user_indexes WHERE table_name = 'TMP_POSICOES' AND index_name = 'UK_TMP_POSICOES';

-- Limpeza
DROP TABLE tmp_posicoes PURGE;
DROP TABLE tmp_exceptions PURGE;
DROP TABLE tmp_valores PURGE;
