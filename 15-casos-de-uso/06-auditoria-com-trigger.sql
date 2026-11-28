-- =============================================================================
-- Caso   : Histórico coluna a coluna de alterações em clientes, com trigger
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE TRIGGER
--
-- Trabalha numa cópia de CLIENTES (TMP_CLIENTES), removida no fim.
-- =============================================================================

SET LINESIZE 200
COLUMN coluna       FORMAT A16
COLUMN valor_antigo FORMAT A34
COLUMN valor_novo   FORMAT A34
COLUMN usuario      FORMAT A10
COLUMN modulo       FORMAT A16

CREATE TABLE tmp_clientes AS SELECT * FROM clientes;
ALTER TABLE tmp_clientes ADD CONSTRAINT pk_tmp_clientes PRIMARY KEY (id_cliente);

CREATE TABLE tmp_hist_alteracoes (
    id_hist      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabela       VARCHAR2(30)   NOT NULL,
    chave        VARCHAR2(100)  NOT NULL,
    operacao     CHAR(1)        NOT NULL,
    coluna       VARCHAR2(30),
    valor_antigo VARCHAR2(4000),
    valor_novo   VARCHAR2(4000),
    usuario      VARCHAR2(128)  DEFAULT USER NOT NULL,
    modulo       VARCHAR2(64)   DEFAULT SYS_CONTEXT('USERENV', 'MODULE'),
    maquina      VARCHAR2(64)   DEFAULT SYS_CONTEXT('USERENV', 'HOST'),
    momento      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX tmp_ix_hist_chave ON tmp_hist_alteracoes (tabela, chave, momento);

-- 1. O trigger.
CREATE OR REPLACE TRIGGER tmp_trg_clientes_hist
    AFTER INSERT OR UPDATE OR DELETE ON tmp_clientes
    FOR EACH ROW
DECLARE
    v_chave VARCHAR2(100) := TO_CHAR(NVL(:NEW.id_cliente, :OLD.id_cliente));

    PROCEDURE registrar (p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        -- DECODE trata NULL = NULL: registra também a troca de NULL por valor e vice-versa.
        IF DECODE(p_antigo, p_novo, 0, 1) = 1 THEN
            INSERT INTO tmp_hist_alteracoes (tabela, chave, operacao, coluna, valor_antigo, valor_novo)
            VALUES ('CLIENTES', v_chave, 'U', p_coluna, p_antigo, p_novo);
        END IF;
    END;
BEGIN
    IF UPDATING THEN
        registrar('LIMITE_CREDITO', TO_CHAR(:OLD.limite_credito), TO_CHAR(:NEW.limite_credito));
        registrar('EMAIL',          :OLD.email,                   :NEW.email);
        registrar('CIDADE',         :OLD.cidade,                  :NEW.cidade);
        registrar('ATIVO',          :OLD.ativo,                   :NEW.ativo);
    ELSIF INSERTING THEN
        INSERT INTO tmp_hist_alteracoes (tabela, chave, operacao, valor_novo)
        VALUES ('CLIENTES', v_chave, 'I', :NEW.nome || ' | limite ' || :NEW.limite_credito);
    ELSE
        INSERT INTO tmp_hist_alteracoes (tabela, chave, operacao, valor_antigo)
        VALUES ('CLIENTES', v_chave, 'D', :OLD.nome || ' | limite ' || :OLD.limite_credito);
    END IF;
END;
/

-- 2. Alterações de teste, identificando o "módulo" como faria uma aplicação.
EXEC DBMS_APPLICATION_INFO.SET_MODULE('tmp_tela_credito', NULL)

UPDATE tmp_clientes SET limite_credito = 55000 WHERE id_cliente = 1;

UPDATE tmp_clientes
   SET email  = 'compras@escritoriomodelo.example',
       cidade = 'Contagem'
 WHERE id_cliente = 3;

-- Sem mudança real: não deve gerar histórico.
UPDATE tmp_clientes SET limite_credito = limite_credito WHERE id_cliente = 2;

DELETE FROM tmp_clientes WHERE id_cliente = 12;

INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, cidade, uf, data_cadastro, limite_credito, ativo)
VALUES (50, 'Cliente Novo Ltda', 'J', '10000000000150', 'Palmas', 'TO', DATE '2026-11-27', 15000, 'S');

COMMIT;
EXEC DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL)

-- 3. O histórico.
-- Esperado: 5 linhas
--   1  U LIMITE_CREDITO 50000                            55000
--   3  U EMAIL          (vazio)                          compras@escritoriomodelo.example
--   3  U CIDADE         Belo Horizonte                   Contagem
--   12 D                Thiago Nunes | limite 2000
--   50 I                                                 Cliente Novo Ltda | limite 15000
--   todas com usuario ESTUDO e modulo tmp_tela_credito
SELECT chave, operacao, coluna, valor_antigo, valor_novo, usuario, modulo
  FROM tmp_hist_alteracoes
 ORDER BY id_hist;

-- 4. Perguntas do negócio.
-- Quem mexeu no limite de crédito, e quanto.
-- Esperado: cliente 1, de 50000 para 55000 (+10%), por ESTUDO
SELECT h.chave AS cliente,
       h.valor_antigo, h.valor_novo,
       ROUND(100 * (TO_NUMBER(h.valor_novo) / TO_NUMBER(h.valor_antigo) - 1), 1) AS variacao_pct,
       h.usuario,
       TO_CHAR(h.momento, 'DD/MM/YYYY HH24:MI') AS quando
  FROM tmp_hist_alteracoes h
 WHERE h.coluna = 'LIMITE_CREDITO';

-- Qual era o valor de uma coluna num instante: o valor_antigo da primeira alteração
-- depois do instante, ou o atual se não houve alteração depois.
-- Esperado: 50000 (o limite do cliente 1 antes da alteração feita acima)
SELECT NVL((SELECT h.valor_antigo
              FROM tmp_hist_alteracoes h
             WHERE h.tabela = 'CLIENTES' AND h.chave = '1' AND h.coluna = 'LIMITE_CREDITO'
               AND h.momento > SYSTIMESTAMP - INTERVAL '1' DAY
             ORDER BY h.momento
             FETCH FIRST 1 ROW ONLY),
           (SELECT TO_CHAR(limite_credito) FROM tmp_clientes WHERE id_cliente = 1)) AS limite_no_instante
  FROM dual;

-- 5. DML desfeito: o histórico vai junto.
UPDATE tmp_clientes SET ativo = 'N' WHERE id_cliente = 4;
ROLLBACK;

-- Esperado: 5 (nada de novo)
SELECT COUNT(*) FROM tmp_hist_alteracoes;

DROP TABLE tmp_clientes PURGE;
DROP TABLE tmp_hist_alteracoes PURGE;
