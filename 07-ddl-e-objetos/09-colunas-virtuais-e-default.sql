-- =============================================================================
-- Tópico : Colunas virtuais, DEFAULT e colunas invisíveis
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

-- Cópia de itens_pedido com coluna virtual para o valor líquido.
CREATE TABLE tmp_itens (
    id_pedido       NUMBER(8)     NOT NULL,
    nr_item         NUMBER(3)     NOT NULL,
    id_produto      NUMBER(6)     NOT NULL,
    quantidade      NUMBER(10,3)  NOT NULL,
    preco_unitario  NUMBER(10,2)  NOT NULL,
    pct_desconto    NUMBER(5,2)   DEFAULT 0 NOT NULL,
    valor_bruto     AS (quantidade * preco_unitario),
    valor_liquido   NUMBER(12,2)  GENERATED ALWAYS AS
                        (ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)) VIRTUAL,
    criado_por      VARCHAR2(128) DEFAULT USER NOT NULL,
    criado_em       DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_tmp_itens PRIMARY KEY (id_pedido, nr_item),
    CONSTRAINT ck_tmp_itens_liquido CHECK (valor_liquido >= 0)
);

-- 1. Carga: as colunas virtuais e as de DEFAULT ficam fora da lista.
INSERT INTO tmp_itens (id_pedido, nr_item, id_produto, quantidade, preco_unitario, pct_desconto)
SELECT id_pedido, nr_item, id_produto, quantidade, preco_unitario, pct_desconto
  FROM itens_pedido;

-- Esperado: 54 linhas; soma do valor líquido = 122815.43 (o mesmo da conferência da carga)
SELECT COUNT(*) AS itens, SUM(valor_liquido) AS total_liquido FROM tmp_itens;

-- A coluna virtual responde como qualquer coluna, inclusive no WHERE e no GROUP BY.
-- Esperado: pedido 1002 -> bruto 17802 | líquido 16276.50
SELECT id_pedido, SUM(valor_bruto) AS bruto, SUM(valor_liquido) AS liquido
  FROM tmp_itens
 WHERE id_pedido = 1002
 GROUP BY id_pedido;

-- Quem e quando, pelos DEFAULTs.
SELECT DISTINCT criado_por, TRUNC(criado_em) AS dia FROM tmp_itens;

-- 2. Coluna virtual não recebe valor.
-- Esperado: ORA-54013 (a operação INSERT não é permitida em colunas virtuais)
INSERT INTO tmp_itens (id_pedido, nr_item, id_produto, quantidade, preco_unitario, valor_liquido)
VALUES (9999, 1, 1, 1, 10, 10);

-- 3. CHECK sobre a coluna virtual: desconto acima de 100% gera líquido negativo.
--    (aqui o CHECK da coluna pct_desconto não existe nesta cópia)
-- Esperado: ORA-02290 (CK_TMP_ITENS_LIQUIDO)
INSERT INTO tmp_itens (id_pedido, nr_item, id_produto, quantidade, preco_unitario, pct_desconto)
VALUES (9999, 1, 1, 1, 10, 150);

-- 4. Índice na coluna virtual.
CREATE INDEX tmp_ix_itens_liquido ON tmp_itens (valor_liquido);

-- Esperado: 8 itens com valor líquido acima de 5000
SELECT COUNT(*) FROM tmp_itens WHERE valor_liquido > 5000;

-- 5. Expressão não permitida: SYSDATE.
-- Esperado: ORA-54002 (somente funções puras podem ser especificadas em uma expressão de coluna virtual)
ALTER TABLE tmp_itens ADD (idade_dias AS (TRUNC(SYSDATE) - TRUNC(criado_em)));

-- 6. Coluna invisível: some do SELECT * e do INSERT sem lista.
ALTER TABLE tmp_itens ADD (lote VARCHAR2(20) INVISIBLE);

-- Esperado: a coluna LOTE não aparece
SELECT * FROM tmp_itens WHERE id_pedido = 1001 AND nr_item = 1;

-- Citada pelo nome, funciona.
UPDATE tmp_itens SET lote = 'L-2025-01' WHERE id_pedido = 1001;

-- Esperado: L-2025-01 nas 3 linhas do pedido 1001
SELECT id_pedido, nr_item, lote FROM tmp_itens WHERE id_pedido = 1001;

-- Dicionário: virtual e hidden.
SELECT column_name, virtual_column, hidden_column, data_default
  FROM user_tab_cols
 WHERE table_name = 'TMP_ITENS'
 ORDER BY internal_column_id;

ROLLBACK;

-- Limpeza
DROP TABLE tmp_itens PURGE;
