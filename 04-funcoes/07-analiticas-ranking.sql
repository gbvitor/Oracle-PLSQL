-- =============================================================================
-- Tópico : Funções analíticas I — ROW_NUMBER, RANK, DENSE_RANK, NTILE
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Analítica mantém as linhas; agregação colapsa.
-- Esperado: 14 linhas, cada uma com a média do seu departamento
SELECT nome,
       id_departamento,
       salario,
       ROUND(AVG(salario) OVER (PARTITION BY id_departamento), 2) AS media_depto
  FROM funcionarios
 ORDER BY id_departamento, salario DESC;

-- 2. As três numerações com empate (104 e 105 têm comissão 5).
-- Esperado:
--   ROW_NUMBER 1, 2, 3, 4, 5
--   RANK       1, 1, 3, 4, 5
--   DENSE_RANK 1, 1, 2, 3, 4
SELECT nome,
       pct_comissao,
       ROW_NUMBER() OVER (ORDER BY pct_comissao DESC, id_funcionario) AS row_number_,
       RANK()       OVER (ORDER BY pct_comissao DESC)                 AS rank_,
       DENSE_RANK() OVER (ORDER BY pct_comissao DESC)                 AS dense_rank_
  FROM funcionarios
 WHERE pct_comissao IS NOT NULL
 ORDER BY pct_comissao DESC, id_funcionario;

-- 3. Ranking de vendedores por valor vendido (sem cancelados).
-- Esperado: 108 1o (49.65%) | 106 2o | 104 3o | 105 4o | site 5o | 107 6o
WITH vendas AS (
    SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS total
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_vendedor
)
SELECT vendedor,
       total,
       RANK() OVER (ORDER BY total DESC)                    AS posicao,
       ROUND(100 * total / SUM(total) OVER (), 2)           AS pct_do_total
  FROM vendas
 ORDER BY posicao;

-- 4. Top-N por grupo: produto mais vendido (em quantidade) de cada categoria.
-- Esperado: cat 2 -> 1 Mouse (49) | 3 -> 5 SSD (53) | 5 -> 8 Papel (305)
--           6 -> 11 Mesa (24)     | 7 -> 13 Cadeira giratoria (53)
SELECT id_categoria, id_produto, nome, qtd
  FROM (SELECT pr.id_categoria,
               pr.id_produto,
               pr.nome,
               SUM(i.quantidade) AS qtd,
               ROW_NUMBER() OVER (PARTITION BY pr.id_categoria
                                  ORDER BY SUM(i.quantidade) DESC, pr.id_produto) AS rn
          FROM itens_pedido i
          JOIN produtos     pr ON pr.id_produto = i.id_produto
         GROUP BY pr.id_categoria, pr.id_produto, pr.nome)
 WHERE rn = 1
 ORDER BY id_categoria;

-- Observação: a função analítica pode usar uma agregação (SUM) porque é
-- calculada depois do GROUP BY.

-- 5. Filtrar pela função no mesmo nível dá erro.
-- Esperado: ORA-30483 (funções de janela não são permitidas aqui)
SELECT nome FROM funcionarios WHERE ROW_NUMBER() OVER (ORDER BY salario DESC) = 1;

-- 6. NTILE: quartis de clientes por valor comprado.
--    10 clientes em 4 grupos: 3, 3, 2, 2.
-- Esperado: quartil 1 -> 10, 3, 2 | 2 -> 6, 1, 8 | 3 -> 9, 7 | 4 -> 5, 4
WITH compras AS (
    SELECT p.id_cliente,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS total
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_cliente
)
SELECT id_cliente,
       total,
       NTILE(4)       OVER (ORDER BY total DESC) AS quartil,
       ROUND(PERCENT_RANK() OVER (ORDER BY total), 2) AS percent_rank_,
       ROUND(CUME_DIST()    OVER (ORDER BY total), 2) AS cume_dist_
  FROM compras
 ORDER BY total DESC;

-- 7. Deduplicação com ROW_NUMBER e ROWID.
--    Tabela de teste com contatos repetidos por e-mail.
CREATE TABLE tmp_contatos AS
SELECT id_cliente, email, data_cadastro FROM clientes WHERE email IS NOT NULL;

INSERT INTO tmp_contatos
SELECT id_cliente, email, data_cadastro + 30 FROM clientes WHERE id_cliente IN (1, 2);

-- Esperado: 11 linhas, 9 e-mails distintos
SELECT COUNT(*) AS linhas, COUNT(DISTINCT email) AS emails FROM tmp_contatos;

-- Manter só o registro mais recente de cada e-mail.
-- Esperado: 2 linhas apagadas
DELETE FROM tmp_contatos
 WHERE ROWID IN (SELECT rid
                   FROM (SELECT ROWID AS rid,
                                ROW_NUMBER() OVER (PARTITION BY email
                                                   ORDER BY data_cadastro DESC) AS rn
                           FROM tmp_contatos)
                  WHERE rn > 1);

-- Esperado: 9 linhas, 9 e-mails
SELECT COUNT(*) AS linhas, COUNT(DISTINCT email) AS emails FROM tmp_contatos;

DROP TABLE tmp_contatos PURGE;
