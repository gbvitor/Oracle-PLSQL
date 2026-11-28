-- =============================================================================
-- Projeto : 01 — Controle de estoque — tabelas
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : CREATE TABLE, CREATE SEQUENCE
-- =============================================================================

CREATE TABLE est_depositos (
    id_deposito  NUMBER(4)     CONSTRAINT pk_est_depositos PRIMARY KEY,
    nome         VARCHAR2(60)  NOT NULL CONSTRAINT uk_est_depositos_nome UNIQUE
);

CREATE TABLE est_produtos (
    id_produto      NUMBER(6)      CONSTRAINT pk_est_produtos PRIMARY KEY,
    codigo          VARCHAR2(20)   NOT NULL CONSTRAINT uk_est_produtos_codigo UNIQUE,
    descricao       VARCHAR2(100)  NOT NULL,
    unidade         VARCHAR2(5)    NOT NULL,
    estoque_minimo  NUMBER(12,3)   DEFAULT 0 NOT NULL
                    CONSTRAINT ck_est_produtos_minimo CHECK (estoque_minimo >= 0),
    ativo           CHAR(1)        DEFAULT 'S' NOT NULL
                    CONSTRAINT ck_est_produtos_ativo CHECK (ativo IN ('S', 'N'))
);

-- Saldo materializado: uma linha por produto e depósito, mantida só pela package.
-- O CHECK é a última barreira: mesmo um UPDATE direto não deixa o saldo negativo.
CREATE TABLE est_saldos (
    id_produto     NUMBER(6)     NOT NULL
                   CONSTRAINT fk_est_saldos_produto REFERENCES est_produtos,
    id_deposito    NUMBER(4)     NOT NULL
                   CONSTRAINT fk_est_saldos_deposito REFERENCES est_depositos,
    quantidade     NUMBER(12,3)  DEFAULT 0 NOT NULL
                   CONSTRAINT ck_est_saldos_qtd CHECK (quantidade >= 0),
    atualizado_em  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_est_saldos PRIMARY KEY (id_produto, id_deposito)
);

CREATE INDEX est_ix_saldos_deposito ON est_saldos (id_deposito);

-- Movimentos: histórico imutável. Quantidade sempre positiva; o sentido está em SINAL.
CREATE TABLE est_movimentos (
    id_movimento      NUMBER GENERATED ALWAYS AS IDENTITY
                      CONSTRAINT pk_est_movimentos PRIMARY KEY,
    id_produto        NUMBER(6)      NOT NULL
                      CONSTRAINT fk_est_mov_produto REFERENCES est_produtos,
    id_deposito       NUMBER(4)      NOT NULL
                      CONSTRAINT fk_est_mov_deposito REFERENCES est_depositos,
    tipo              VARCHAR2(14)   NOT NULL
                      CONSTRAINT ck_est_mov_tipo
                      CHECK (tipo IN ('ENTRADA', 'SAIDA', 'AJUSTE', 'TRANSF_SAIDA', 'TRANSF_ENTRADA')),
    sinal             NUMBER(1)      NOT NULL
                      CONSTRAINT ck_est_mov_sinal CHECK (sinal IN (1, -1)),
    quantidade        NUMBER(12,3)   NOT NULL
                      CONSTRAINT ck_est_mov_qtd CHECK (quantidade > 0),
    data_movimento    DATE           NOT NULL,
    documento         VARCHAR2(30),
    observacao        VARCHAR2(200),
    id_transferencia  NUMBER,
    usuario           VARCHAR2(128)  DEFAULT USER NOT NULL,
    registrado_em     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    -- O tipo determina o sinal, exceto no ajuste (que pode ser para mais ou para menos).
    CONSTRAINT ck_est_mov_tipo_sinal CHECK (
           (tipo IN ('ENTRADA', 'TRANSF_ENTRADA') AND sinal = 1)
        OR (tipo IN ('SAIDA', 'TRANSF_SAIDA')     AND sinal = -1)
        OR  tipo = 'AJUSTE'),
    -- Transferência sempre tem o número que liga a saída à entrada.
    CONSTRAINT ck_est_mov_transf CHECK (
           (tipo LIKE 'TRANSF%' AND id_transferencia IS NOT NULL)
        OR (tipo NOT LIKE 'TRANSF%' AND id_transferencia IS NULL))
);

CREATE INDEX est_ix_mov_kardex   ON est_movimentos (id_produto, id_deposito, data_movimento);
CREATE INDEX est_ix_mov_deposito ON est_movimentos (id_deposito);

CREATE SEQUENCE est_seq_transferencia;
