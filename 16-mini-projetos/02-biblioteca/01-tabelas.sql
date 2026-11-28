-- =============================================================================
-- Projeto : 02 — Biblioteca — tabelas
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : CREATE TABLE
-- =============================================================================

-- Regras por categoria de leitor: quantos livros, por quantos dias, multa e renovações.
CREATE TABLE bib_categorias_leitor (
    categoria        VARCHAR2(10)  CONSTRAINT pk_bib_categorias PRIMARY KEY,
    max_emprestimos  NUMBER(2)     NOT NULL CONSTRAINT ck_bib_cat_max CHECK (max_emprestimos > 0),
    dias_prazo       NUMBER(3)     NOT NULL CONSTRAINT ck_bib_cat_dias CHECK (dias_prazo > 0),
    multa_dia        NUMBER(6,2)   NOT NULL CONSTRAINT ck_bib_cat_multa CHECK (multa_dia >= 0),
    max_renovacoes   NUMBER(2)     NOT NULL CONSTRAINT ck_bib_cat_renov CHECK (max_renovacoes >= 0)
);

CREATE TABLE bib_leitores (
    id_leitor  NUMBER(6)     CONSTRAINT pk_bib_leitores PRIMARY KEY,
    nome       VARCHAR2(100) NOT NULL,
    categoria  VARCHAR2(10)  NOT NULL CONSTRAINT fk_bib_leitores_cat REFERENCES bib_categorias_leitor,
    ativo      CHAR(1)       DEFAULT 'S' NOT NULL CONSTRAINT ck_bib_leitores_ativo CHECK (ativo IN ('S', 'N'))
);

CREATE INDEX bib_ix_leitores_cat ON bib_leitores (categoria);

-- Obra é o título; exemplar é o volume físico que se empresta.
CREATE TABLE bib_obras (
    id_obra  NUMBER(6)     CONSTRAINT pk_bib_obras PRIMARY KEY,
    titulo   VARCHAR2(200) NOT NULL,
    autor    VARCHAR2(100) NOT NULL,
    ano      NUMBER(4)
);

CREATE TABLE bib_exemplares (
    id_exemplar  NUMBER(8)     CONSTRAINT pk_bib_exemplares PRIMARY KEY,
    id_obra      NUMBER(6)     NOT NULL CONSTRAINT fk_bib_exemplares_obra REFERENCES bib_obras,
    situacao     VARCHAR2(10)  DEFAULT 'DISPONIVEL' NOT NULL
                 CONSTRAINT ck_bib_exemplares_sit
                 CHECK (situacao IN ('DISPONIVEL', 'EMPRESTADO', 'RESERVADO', 'BAIXADO'))
);

CREATE INDEX bib_ix_exemplares_obra ON bib_exemplares (id_obra, situacao);

CREATE TABLE bib_emprestimos (
    id_emprestimo    NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_bib_emprestimos PRIMARY KEY,
    id_exemplar      NUMBER(8)    NOT NULL CONSTRAINT fk_bib_emp_exemplar REFERENCES bib_exemplares,
    id_leitor        NUMBER(6)    NOT NULL CONSTRAINT fk_bib_emp_leitor REFERENCES bib_leitores,
    data_emprestimo  DATE         NOT NULL,
    data_prevista    DATE         NOT NULL,
    data_devolucao   DATE,
    renovacoes       NUMBER(2)    DEFAULT 0 NOT NULL,
    valor_multa      NUMBER(8,2)  DEFAULT 0 NOT NULL CONSTRAINT ck_bib_emp_multa CHECK (valor_multa >= 0),
    multa_paga       CHAR(1)      DEFAULT 'N' NOT NULL CONSTRAINT ck_bib_emp_paga CHECK (multa_paga IN ('S', 'N')),
    CONSTRAINT ck_bib_emp_datas CHECK (data_prevista >= data_emprestimo
                                       AND (data_devolucao IS NULL OR data_devolucao >= data_emprestimo))
);

-- Um exemplar só pode ter um empréstimo aberto: índice único só sobre as linhas
-- sem devolução (para as devolvidas a expressão dá NULL, e NULL não entra no índice).
CREATE UNIQUE INDEX bib_ux_emprestimo_aberto
    ON bib_emprestimos (CASE WHEN data_devolucao IS NULL THEN id_exemplar END);

CREATE INDEX bib_ix_emp_leitor   ON bib_emprestimos (id_leitor, data_devolucao);
CREATE INDEX bib_ix_emp_exemplar ON bib_emprestimos (id_exemplar);

-- Reserva: ATIVA (na fila) -> DISPONIVEL (exemplar separado, aguardando retirada)
--          -> ATENDIDA; ou CANCELADA; ou EXPIRADA (não retirou no prazo).
CREATE TABLE bib_reservas (
    id_reserva      NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_bib_reservas PRIMARY KEY,
    id_obra         NUMBER(6)    NOT NULL CONSTRAINT fk_bib_res_obra REFERENCES bib_obras,
    id_leitor       NUMBER(6)    NOT NULL CONSTRAINT fk_bib_res_leitor REFERENCES bib_leitores,
    data_reserva    DATE         NOT NULL,
    situacao        VARCHAR2(10) DEFAULT 'ATIVA' NOT NULL
                    CONSTRAINT ck_bib_res_sit
                    CHECK (situacao IN ('ATIVA', 'DISPONIVEL', 'ATENDIDA', 'CANCELADA', 'EXPIRADA')),
    id_exemplar     NUMBER(8)    CONSTRAINT fk_bib_res_exemplar REFERENCES bib_exemplares,
    prazo_retirada  DATE,
    CONSTRAINT ck_bib_res_disponivel CHECK (
        situacao <> 'DISPONIVEL' OR (id_exemplar IS NOT NULL AND prazo_retirada IS NOT NULL))
);

-- Uma reserva aberta (ATIVA ou DISPONIVEL) por leitor e obra.
CREATE UNIQUE INDEX bib_ux_reserva_aberta
    ON bib_reservas (CASE WHEN situacao IN ('ATIVA', 'DISPONIVEL') THEN id_leitor END,
                     CASE WHEN situacao IN ('ATIVA', 'DISPONIVEL') THEN id_obra END);

CREATE INDEX bib_ix_res_fila     ON bib_reservas (id_obra, situacao, data_reserva);
CREATE INDEX bib_ix_res_leitor   ON bib_reservas (id_leitor);
CREATE INDEX bib_ix_res_exemplar ON bib_reservas (id_exemplar);
