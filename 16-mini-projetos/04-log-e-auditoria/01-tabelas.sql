-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — tabelas
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : CREATE TABLE
-- =============================================================================

-- Uma linha por execução de processo (job, carga, rotina chamada pela tela).
CREATE TABLE log_execucoes (
    id_execucao  NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_log_execucoes PRIMARY KEY,
    modulo       VARCHAR2(64)   NOT NULL,
    inicio       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    fim          TIMESTAMP,
    situacao     VARCHAR2(10)   DEFAULT 'EXECUTANDO' NOT NULL
                 CONSTRAINT ck_log_exec_sit CHECK (situacao IN ('EXECUTANDO', 'OK', 'ERRO')),
    usuario      VARCHAR2(128)  DEFAULT USER NOT NULL,
    sid          NUMBER
);

CREATE INDEX log_ix_exec_inicio ON log_execucoes (inicio);

-- Eventos de log. Gravados em transação autônoma: ficam mesmo se o processo fizer ROLLBACK.
CREATE TABLE log_eventos (
    id_evento    NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_log_eventos PRIMARY KEY,
    momento      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    nivel        VARCHAR2(5)    NOT NULL
                 CONSTRAINT ck_log_ev_nivel CHECK (nivel IN ('DEBUG', 'INFO', 'AVISO', 'ERRO')),
    id_execucao  NUMBER         CONSTRAINT fk_log_ev_execucao REFERENCES log_execucoes,
    modulo       VARCHAR2(64),
    mensagem     VARCHAR2(4000) NOT NULL,
    detalhe      CLOB,
    usuario      VARCHAR2(128)  DEFAULT USER NOT NULL,
    sid          NUMBER
);

CREATE INDEX log_ix_ev_momento  ON log_eventos (momento);
CREATE INDEX log_ix_ev_execucao ON log_eventos (id_execucao);

-- Auditoria de alterações: uma linha por coluna alterada. Gravada na MESMA
-- transação da alteração: se ela for desfeita, a auditoria também é.
CREATE TABLE log_aud_alteracoes (
    id_alteracao  NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_log_aud PRIMARY KEY,
    momento       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    usuario       VARCHAR2(128)  DEFAULT USER NOT NULL,
    id_execucao   NUMBER,
    tabela        VARCHAR2(128)  NOT NULL,
    chave         VARCHAR2(400)  NOT NULL,
    operacao      CHAR(1)        NOT NULL CONSTRAINT ck_log_aud_op CHECK (operacao IN ('I', 'U', 'D')),
    coluna        VARCHAR2(128)  NOT NULL,
    valor_antigo  VARCHAR2(4000),
    valor_novo    VARCHAR2(4000)
);

CREATE INDEX log_ix_aud_chave   ON log_aud_alteracoes (tabela, chave, momento);
CREATE INDEX log_ix_aud_momento ON log_aud_alteracoes (momento);
