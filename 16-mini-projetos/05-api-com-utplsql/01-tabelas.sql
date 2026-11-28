-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — tabela
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : CREATE TABLE
-- =============================================================================

CREATE TABLE api_clientes (
    id_cliente      NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_api_clientes PRIMARY KEY,
    tipo_pessoa     CHAR(1)        NOT NULL CONSTRAINT ck_api_cli_tipo CHECK (tipo_pessoa IN ('F', 'J')),
    -- Sem máscara. Texto: CPF e CNPJ têm zero à esquerda e o CNPJ pode ter letras.
    documento       VARCHAR2(14)   NOT NULL CONSTRAINT uk_api_clientes_documento UNIQUE,
    nome            VARCHAR2(100)  NOT NULL,
    email           VARCHAR2(120),
    uf              CHAR(2)        NOT NULL,
    limite_credito  NUMBER(12,2)   DEFAULT 0 NOT NULL CONSTRAINT ck_api_cli_limite CHECK (limite_credito >= 0),
    ativo           CHAR(1)        DEFAULT 'S' NOT NULL CONSTRAINT ck_api_cli_ativo CHECK (ativo IN ('S', 'N')),
    -- Controle de concorrência otimista: toda alteração soma 1.
    versao          NUMBER(9)      DEFAULT 1 NOT NULL,
    criado_em       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    criado_por      VARCHAR2(128)  DEFAULT USER NOT NULL,
    alterado_em     TIMESTAMP,
    alterado_por    VARCHAR2(128)
);

CREATE INDEX api_ix_clientes_uf ON api_clientes (uf, nome);
