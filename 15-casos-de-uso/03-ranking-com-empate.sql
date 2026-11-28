-- =============================================================================
-- Caso   : Ranking de vendedores — ROW_NUMBER, RANK, DENSE_RANK, por ano,
--          top N com empate, quartis, participação
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
--
-- Vendas = valor líquido dos itens de pedidos não cancelados.
-- =============================================================================

COLUMN vendedor FORMAT A16
COLUMN valor    FORMAT 999G990D00

-- 1. Por número de pedidos: os três tratamentos de empate lado a lado.
-- Esperado:
--   VENDEDOR        PEDIDOS  ROW_NUMBER  RANK  DENSE_RANK
--   Eduarda Lima          6           1     1           1
--   Felipe Souza          4           2     2           2
--   Gabriela Rocha        4           3     2           2
--   Henrique Alves        3           4     4           3
--   Isabela Costa         3           5     4           3
--   (desempate do ROW_NUMBER pelo nome, para ser sempre o mesmo)
SELECT f.nome AS vendedor,
       COUNT(*) AS pedidos,
       ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, f.nome) AS row_number,
       RANK()       OVER (ORDER BY COUNT(*) DESC)         AS rank,
       DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)         AS dense_rank
  FROM pedidos p
  JOIN funcionarios f ON f.id_funcionario = p.id_vendedor
 WHERE p.status <> 'CANCELADO'
 GROUP BY f.nome
 ORDER BY pedidos DESC, f.nome;

-- 2. "Top 2 por número de pedidos": RANK devolve três pessoas (empate no segundo lugar).
-- Esperado: Eduarda Lima, Felipe Souza, Gabriela Rocha
SELECT vendedor, pedidos
  FROM (SELECT f.nome AS vendedor,
               COUNT(*) AS pedidos,
               RANK() OVER (ORDER BY COUNT(*) DESC) AS posicao
          FROM pedidos p
          JOIN funcionarios f ON f.id_funcionario = p.id_vendedor
         WHERE p.status <> 'CANCELADO'
         GROUP BY f.nome)
 WHERE posicao <= 2
 ORDER BY pedidos DESC, vendedor;

-- 3. Por valor, com participação e o total conferido (o site fica fora do ranking,
--    mas entra no total).
-- Esperado:
--   1 Isabela Costa   60.081,58  49,6%
--   2 Gabriela Rocha  30.501,92  25,2%
--   3 Eduarda Lima    13.052,25  10,8%
--   4 Felipe Souza    10.512,88   8,7%
--   5 Henrique Alves   3.199,40   2,6%
--   - (site)           3.669,40   3,0%
--   total: 121.017,43
WITH vendas AS (
    SELECT p.id_vendedor,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_vendedor
)
SELECT CASE WHEN v.id_vendedor IS NOT NULL
            THEN TO_CHAR(RANK() OVER (ORDER BY CASE WHEN v.id_vendedor IS NULL THEN 0 ELSE v.valor END DESC))
            ELSE '-'
       END AS posicao,
       NVL(f.nome, '(site)') AS vendedor,
       v.valor,
       ROUND(100 * RATIO_TO_REPORT(v.valor) OVER (), 1) AS pct,
       SUM(v.valor) OVER () AS total
  FROM vendas v
  LEFT JOIN funcionarios f ON f.id_funcionario = v.id_vendedor
 ORDER BY CASE WHEN v.id_vendedor IS NULL THEN 1 ELSE 0 END, v.valor DESC;

-- 4. Ranking por ano.
-- Esperado:
--   2025: 1 Isabela 43.248,70 | 2 Gabriela 21.439,94 | 3 Felipe 10.343,18 |
--         4 Eduarda 7.462,61 | 5 Henrique 2.300,40
--   2026: 1 Isabela 16.832,88 | 2 Gabriela 9.061,98 | 3 Eduarda 5.589,64 |
--         4 Henrique 899,00 | 5 Felipe 169,70
SELECT EXTRACT(YEAR FROM p.data_pedido) AS ano,
       RANK() OVER (PARTITION BY EXTRACT(YEAR FROM p.data_pedido)
                    ORDER BY SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) DESC) AS posicao,
       f.nome AS vendedor,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
  JOIN funcionarios f ON f.id_funcionario = p.id_vendedor
 WHERE p.status <> 'CANCELADO'
 GROUP BY EXTRACT(YEAR FROM p.data_pedido), f.nome
 ORDER BY ano, posicao;

-- 5. Quem subiu e quem caiu de um ano para o outro.
-- Esperado: Eduarda +1 (4 para 3) | Henrique +1 (5 para 4) | Felipe -2 (3 para 5) |
--           Isabela e Gabriela 0
WITH r AS (
    SELECT EXTRACT(YEAR FROM p.data_pedido) AS ano,
           f.nome AS vendedor,
           RANK() OVER (PARTITION BY EXTRACT(YEAR FROM p.data_pedido)
                        ORDER BY SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) DESC) AS posicao
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
      JOIN funcionarios f ON f.id_funcionario = p.id_vendedor
     WHERE p.status <> 'CANCELADO'
     GROUP BY EXTRACT(YEAR FROM p.data_pedido), f.nome
)
SELECT a.vendedor, a.posicao AS pos_2025, b.posicao AS pos_2026, a.posicao - b.posicao AS subiu
  FROM r a
  JOIN r b ON b.vendedor = a.vendedor AND b.ano = 2026
 WHERE a.ano = 2025
 ORDER BY subiu DESC, a.vendedor;

-- 6. Quartis de clientes por valor comprado (NTILE).
-- Esperado: 10 clientes com compra em 4 grupos (3, 3, 2, 2); no 1º quartil os clientes
--           10, 3 e 2 (os maiores)
SELECT NTILE(4) OVER (ORDER BY SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) DESC) AS quartil,
       p.id_cliente,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY p.id_cliente
 ORDER BY quartil, valor DESC;
