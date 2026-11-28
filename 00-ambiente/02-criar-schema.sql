-- =============================================================================
-- Tópico : Schema de exemplo — criação das tabelas
-- Seção  : 00-ambiente
-- Versão : 19c
-- Requer : usuário de estudo (01-criar-usuario.sql) ou conta no FreeSQL
--
-- Distribuidora fictícia de informática, papelaria e móveis de escritório.
-- Sete tabelas: departamentos, funcionarios, clientes, categorias, produtos,
-- pedidos e itens_pedido. Modelo descrito em modelo-de-dados.md.
-- =============================================================================

CREATE TABLE departamentos (
    id_departamento  NUMBER(4)      CONSTRAINT pk_departamentos PRIMARY KEY,
    nome             VARCHAR2(60)   NOT NULL,
    cidade           VARCHAR2(60),
    CONSTRAINT uk_departamentos_nome UNIQUE (nome)
);

CREATE TABLE funcionarios (
    id_funcionario   NUMBER(6)      CONSTRAINT pk_funcionarios PRIMARY KEY,
    nome             VARCHAR2(100)  NOT NULL,
    email            VARCHAR2(120)  NOT NULL,
    cargo            VARCHAR2(40)   NOT NULL,
    salario          NUMBER(10,2)   NOT NULL,
    pct_comissao     NUMBER(5,2),
    data_admissao    DATE           NOT NULL,
    id_gerente       NUMBER(6),
    id_departamento  NUMBER(4),
    CONSTRAINT uk_funcionarios_email     UNIQUE (email),
    CONSTRAINT ck_funcionarios_salario   CHECK (salario > 0),
    CONSTRAINT ck_funcionarios_comissao  CHECK (pct_comissao BETWEEN 0 AND 50),
    CONSTRAINT fk_funcionarios_gerente   FOREIGN KEY (id_gerente)
        REFERENCES funcionarios (id_funcionario),
    CONSTRAINT fk_funcionarios_depto     FOREIGN KEY (id_departamento)
        REFERENCES departamentos (id_departamento)
);

CREATE TABLE clientes (
    id_cliente       NUMBER(6)      CONSTRAINT pk_clientes PRIMARY KEY,
    nome             VARCHAR2(100)  NOT NULL,
    tipo_pessoa      CHAR(1)        NOT NULL,
    documento        VARCHAR2(14)   NOT NULL,
    email            VARCHAR2(120),
    cidade           VARCHAR2(60)   NOT NULL,
    uf               CHAR(2)        NOT NULL,
    data_cadastro    DATE           DEFAULT SYSDATE NOT NULL,
    limite_credito   NUMBER(12,2),
    ativo            CHAR(1)        DEFAULT 'S' NOT NULL,
    CONSTRAINT uk_clientes_documento  UNIQUE (documento),
    CONSTRAINT ck_clientes_tipo       CHECK (tipo_pessoa IN ('F', 'J')),
    CONSTRAINT ck_clientes_ativo      CHECK (ativo IN ('S', 'N'))
);

CREATE TABLE categorias (
    id_categoria      NUMBER(4)     CONSTRAINT pk_categorias PRIMARY KEY,
    nome              VARCHAR2(60)  NOT NULL,
    id_categoria_pai  NUMBER(4),
    CONSTRAINT fk_categorias_pai FOREIGN KEY (id_categoria_pai)
        REFERENCES categorias (id_categoria)
);

CREATE TABLE produtos (
    id_produto       NUMBER(6)      CONSTRAINT pk_produtos PRIMARY KEY,
    nome             VARCHAR2(100)  NOT NULL,
    id_categoria     NUMBER(4)      NOT NULL,
    unidade          VARCHAR2(5)    NOT NULL,
    preco_unitario   NUMBER(10,2)   NOT NULL,
    ativo            CHAR(1)        DEFAULT 'S' NOT NULL,
    CONSTRAINT fk_produtos_categoria  FOREIGN KEY (id_categoria)
        REFERENCES categorias (id_categoria),
    CONSTRAINT ck_produtos_preco      CHECK (preco_unitario >= 0),
    CONSTRAINT ck_produtos_ativo      CHECK (ativo IN ('S', 'N'))
);

CREATE TABLE pedidos (
    id_pedido        NUMBER(8)      CONSTRAINT pk_pedidos PRIMARY KEY,
    id_cliente       NUMBER(6)      NOT NULL,
    id_vendedor      NUMBER(6),
    data_pedido      DATE           NOT NULL,
    status           VARCHAR2(12)   DEFAULT 'ABERTO' NOT NULL,
    observacao       VARCHAR2(400),
    CONSTRAINT fk_pedidos_cliente   FOREIGN KEY (id_cliente)
        REFERENCES clientes (id_cliente),
    CONSTRAINT fk_pedidos_vendedor  FOREIGN KEY (id_vendedor)
        REFERENCES funcionarios (id_funcionario),
    CONSTRAINT ck_pedidos_status    CHECK (status IN ('ABERTO', 'FATURADO', 'ENTREGUE', 'CANCELADO'))
);

CREATE TABLE itens_pedido (
    id_pedido        NUMBER(8)      NOT NULL,
    nr_item          NUMBER(3)      NOT NULL,
    id_produto       NUMBER(6)      NOT NULL,
    quantidade       NUMBER(10,3)   NOT NULL,
    preco_unitario   NUMBER(10,2)   NOT NULL,
    pct_desconto     NUMBER(5,2)    DEFAULT 0 NOT NULL,
    CONSTRAINT pk_itens_pedido          PRIMARY KEY (id_pedido, nr_item),
    CONSTRAINT fk_itens_pedido_pedido   FOREIGN KEY (id_pedido)
        REFERENCES pedidos (id_pedido) ON DELETE CASCADE,
    CONSTRAINT fk_itens_pedido_produto  FOREIGN KEY (id_produto)
        REFERENCES produtos (id_produto),
    CONSTRAINT ck_itens_pedido_qtd      CHECK (quantidade > 0),
    CONSTRAINT ck_itens_pedido_desconto CHECK (pct_desconto BETWEEN 0 AND 100)
);

-- -----------------------------------------------------------------------------
-- Índices nas chaves estrangeiras.
-- O Oracle não cria índice automaticamente em FK; sem ele, DELETE/UPDATE na
-- tabela pai trava a tabela filha inteira e os joins ficam mais caros.
-- -----------------------------------------------------------------------------
CREATE INDEX ix_funcionarios_gerente  ON funcionarios (id_gerente);
CREATE INDEX ix_funcionarios_depto    ON funcionarios (id_departamento);
CREATE INDEX ix_categorias_pai        ON categorias (id_categoria_pai);
CREATE INDEX ix_produtos_categoria    ON produtos (id_categoria);
CREATE INDEX ix_pedidos_cliente       ON pedidos (id_cliente);
CREATE INDEX ix_pedidos_vendedor      ON pedidos (id_vendedor);
CREATE INDEX ix_pedidos_data          ON pedidos (data_pedido);
CREATE INDEX ix_itens_pedido_produto  ON itens_pedido (id_produto);

-- -----------------------------------------------------------------------------
-- Comentários: ficam no dicionário de dados (USER_TAB_COMMENTS e
-- USER_COL_COMMENTS) e são usados como exemplo na seção 10.
-- -----------------------------------------------------------------------------
COMMENT ON TABLE departamentos IS 'Departamentos da empresa';
COMMENT ON TABLE funcionarios  IS 'Funcionarios, id_gerente aponta para o superior imediato';
COMMENT ON TABLE clientes      IS 'Clientes pessoa fisica (F) e juridica (J)';
COMMENT ON TABLE categorias    IS 'Arvore de categorias de produto, id_categoria_pai nulo indica raiz';
COMMENT ON TABLE produtos      IS 'Catalogo de produtos com preco de tabela atual';
COMMENT ON TABLE pedidos       IS 'Cabecalho do pedido de venda';
COMMENT ON TABLE itens_pedido  IS 'Itens do pedido, preco_unitario e o praticado na venda, nao o de tabela';

COMMENT ON COLUMN funcionarios.pct_comissao   IS 'Percentual de comissao sobre vendas (5 = 5%), nulo para quem nao vende';
COMMENT ON COLUMN funcionarios.id_gerente     IS 'Superior imediato, nulo apenas para a diretoria geral';
COMMENT ON COLUMN clientes.documento          IS 'CPF (11 digitos) ou CNPJ (14 digitos), so numeros, valores ficticios';
COMMENT ON COLUMN clientes.limite_credito     IS 'Limite de credito, nulo significa nao analisado';
COMMENT ON COLUMN pedidos.id_vendedor         IS 'Funcionario que fez a venda, nulo para pedido feito pelo site';
COMMENT ON COLUMN itens_pedido.pct_desconto   IS 'Desconto do item em percentual (10 = 10%)';
