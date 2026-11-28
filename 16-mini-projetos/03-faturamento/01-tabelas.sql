-- =============================================================================
-- Projeto : 03 — Faturamento simplificado — tabelas
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : CREATE TABLE
-- =============================================================================

-- Numeração das notas por série: último número usado. Sequence não serve aqui,
-- porque pode pular números (cache, rollback) e a numeração fiscal não pode ter buraco.
CREATE TABLE fat_numeracao (
    serie          VARCHAR2(3)  CONSTRAINT pk_fat_numeracao PRIMARY KEY,
    ultimo_numero  NUMBER(9)    DEFAULT 0 NOT NULL CONSTRAINT ck_fat_num_ultimo CHECK (ultimo_numero >= 0)
);

CREATE TABLE fat_clientes (
    id_cliente      NUMBER(6)     CONSTRAINT pk_fat_clientes PRIMARY KEY,
    nome            VARCHAR2(100) NOT NULL,
    -- NULL = sem limite de crédito.
    limite_credito  NUMBER(12,2)  CONSTRAINT ck_fat_cli_limite CHECK (limite_credito >= 0),
    ativo           CHAR(1)       DEFAULT 'S' NOT NULL CONSTRAINT ck_fat_cli_ativo CHECK (ativo IN ('S', 'N'))
);

CREATE TABLE fat_produtos (
    id_produto  NUMBER(6)     CONSTRAINT pk_fat_produtos PRIMARY KEY,
    descricao   VARCHAR2(100) NOT NULL,
    preco       NUMBER(10,2)  NOT NULL CONSTRAINT ck_fat_prod_preco CHECK (preco >= 0)
);

-- Condição de pagamento e suas parcelas (prazo em dias e percentual do total).
CREATE TABLE fat_condicoes (
    id_condicao  NUMBER(4)    CONSTRAINT pk_fat_condicoes PRIMARY KEY,
    descricao    VARCHAR2(40) NOT NULL
);

CREATE TABLE fat_condicoes_parcelas (
    id_condicao  NUMBER(4)    NOT NULL CONSTRAINT fk_fat_condpar_cond REFERENCES fat_condicoes,
    numero       NUMBER(2)    NOT NULL CONSTRAINT ck_fat_condpar_num CHECK (numero > 0),
    dias         NUMBER(4)    NOT NULL CONSTRAINT ck_fat_condpar_dias CHECK (dias >= 0),
    percentual   NUMBER(5,2)  NOT NULL CONSTRAINT ck_fat_condpar_pct CHECK (percentual > 0 AND percentual <= 100),
    CONSTRAINT pk_fat_condicoes_parcelas PRIMARY KEY (id_condicao, numero)
);

CREATE TABLE fat_pedidos (
    id_pedido    NUMBER(8)     CONSTRAINT pk_fat_pedidos PRIMARY KEY,
    id_cliente   NUMBER(6)     NOT NULL CONSTRAINT fk_fat_ped_cliente REFERENCES fat_clientes,
    id_condicao  NUMBER(4)     NOT NULL CONSTRAINT fk_fat_ped_condicao REFERENCES fat_condicoes,
    data_pedido  DATE          NOT NULL,
    situacao     VARCHAR2(10)  DEFAULT 'ABERTO' NOT NULL
                 CONSTRAINT ck_fat_ped_sit CHECK (situacao IN ('ABERTO', 'FATURADO', 'CANCELADO'))
);

CREATE INDEX fat_ix_ped_cliente  ON fat_pedidos (id_cliente);
CREATE INDEX fat_ix_ped_condicao ON fat_pedidos (id_condicao);

CREATE TABLE fat_itens_pedido (
    id_pedido       NUMBER(8)     NOT NULL CONSTRAINT fk_fat_itped_pedido REFERENCES fat_pedidos,
    item            NUMBER(3)     NOT NULL,
    id_produto      NUMBER(6)     NOT NULL CONSTRAINT fk_fat_itped_produto REFERENCES fat_produtos,
    quantidade      NUMBER(12,3)  NOT NULL CONSTRAINT ck_fat_itped_qtd CHECK (quantidade > 0),
    preco_unitario  NUMBER(10,2)  NOT NULL CONSTRAINT ck_fat_itped_preco CHECK (preco_unitario >= 0),
    pct_desconto    NUMBER(5,2)   DEFAULT 0 NOT NULL
                    CONSTRAINT ck_fat_itped_desc CHECK (pct_desconto BETWEEN 0 AND 100),
    CONSTRAINT pk_fat_itens_pedido PRIMARY KEY (id_pedido, item)
);

CREATE INDEX fat_ix_itped_produto ON fat_itens_pedido (id_produto);

CREATE TABLE fat_notas (
    id_nota              NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_fat_notas PRIMARY KEY,
    serie                VARCHAR2(3)   NOT NULL CONSTRAINT fk_fat_nota_serie REFERENCES fat_numeracao,
    numero               NUMBER(9)     NOT NULL,
    id_pedido            NUMBER(8)     NOT NULL CONSTRAINT fk_fat_nota_pedido REFERENCES fat_pedidos,
    id_cliente           NUMBER(6)     NOT NULL CONSTRAINT fk_fat_nota_cliente REFERENCES fat_clientes,
    data_emissao         DATE          NOT NULL,
    valor_total          NUMBER(12,2)  NOT NULL CONSTRAINT ck_fat_nota_total CHECK (valor_total > 0),
    situacao             VARCHAR2(10)  DEFAULT 'EMITIDA' NOT NULL
                         CONSTRAINT ck_fat_nota_sit CHECK (situacao IN ('EMITIDA', 'CANCELADA')),
    motivo_cancelamento  VARCHAR2(200),
    CONSTRAINT uk_fat_notas_numero UNIQUE (serie, numero),
    CONSTRAINT ck_fat_nota_motivo CHECK (situacao = 'EMITIDA' OR motivo_cancelamento IS NOT NULL)
);

-- Um pedido tem no máximo uma nota emitida; notas canceladas ficam no histórico.
CREATE UNIQUE INDEX fat_ux_nota_pedido_emitida
    ON fat_notas (CASE WHEN situacao = 'EMITIDA' THEN id_pedido END);

CREATE INDEX fat_ix_nota_pedido  ON fat_notas (id_pedido);
CREATE INDEX fat_ix_nota_cliente ON fat_notas (id_cliente);

-- Itens copiados do pedido no faturamento: a nota não muda se o pedido mudar depois.
CREATE TABLE fat_itens_nota (
    id_nota         NUMBER        NOT NULL CONSTRAINT fk_fat_itnota_nota REFERENCES fat_notas,
    item            NUMBER(3)     NOT NULL,
    id_produto      NUMBER(6)     NOT NULL CONSTRAINT fk_fat_itnota_produto REFERENCES fat_produtos,
    quantidade      NUMBER(12,3)  NOT NULL,
    preco_unitario  NUMBER(10,2)  NOT NULL,
    pct_desconto    NUMBER(5,2)   NOT NULL,
    valor           NUMBER(12,2)  NOT NULL,
    CONSTRAINT pk_fat_itens_nota PRIMARY KEY (id_nota, item)
);

CREATE INDEX fat_ix_itnota_produto ON fat_itens_nota (id_produto);

CREATE TABLE fat_titulos (
    id_titulo   NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_fat_titulos PRIMARY KEY,
    id_nota     NUMBER        NOT NULL CONSTRAINT fk_fat_tit_nota REFERENCES fat_notas,
    parcela     NUMBER(2)     NOT NULL,
    vencimento  DATE          NOT NULL,
    valor       NUMBER(12,2)  NOT NULL CONSTRAINT ck_fat_tit_valor CHECK (valor > 0),
    valor_pago  NUMBER(12,2)  DEFAULT 0 NOT NULL,
    situacao    VARCHAR2(10)  DEFAULT 'ABERTO' NOT NULL
                CONSTRAINT ck_fat_tit_sit CHECK (situacao IN ('ABERTO', 'PAGO', 'CANCELADO')),
    CONSTRAINT uk_fat_titulos_parcela UNIQUE (id_nota, parcela),
    CONSTRAINT ck_fat_tit_pago CHECK (valor_pago >= 0 AND valor_pago <= valor),
    CONSTRAINT ck_fat_tit_quitado CHECK (situacao <> 'PAGO' OR valor_pago = valor)
);

-- Baixa: cada pagamento (parcial ou total) de um título, com os encargos de atraso.
CREATE TABLE fat_baixas (
    id_baixa        NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_fat_baixas PRIMARY KEY,
    id_titulo       NUMBER        NOT NULL CONSTRAINT fk_fat_baixa_titulo REFERENCES fat_titulos,
    data_pagamento  DATE          NOT NULL,
    valor           NUMBER(12,2)  NOT NULL CONSTRAINT ck_fat_baixa_valor CHECK (valor > 0),
    encargos        NUMBER(12,2)  DEFAULT 0 NOT NULL CONSTRAINT ck_fat_baixa_enc CHECK (encargos >= 0),
    registrado_em   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX fat_ix_baixa_titulo ON fat_baixas (id_titulo);
