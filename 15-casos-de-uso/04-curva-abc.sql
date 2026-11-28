-- =============================================================================
-- Caso   : Curva ABC de produtos por faturamento
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
--
-- Faturamento = valor líquido dos itens de pedidos não cancelados, todo o período.
-- Total: 121.017,43.
-- =============================================================================

SET LINESIZE 160
SET PAGESIZE 50
COLUMN produto   FORMAT A32
COLUMN valor     FORMAT 999G990D00
COLUMN pct       FORMAT 990D00
COLUMN acumulado FORMAT 990D00

-- 1. A curva completa.
-- Esperado:
--   PRODUTO                         VALOR    PCT  ACUMULADO CLASSE
--   13 Cadeira giratoria         36.297,04  29,99   29,99   A
--    3 Monitor 24 polegadas      18.245,20  15,08   45,07   A
--   11 Mesa de escritorio 1,20 m 13.564,80  11,21   56,28   A
--    5 SSD 480 GB                11.465,83   9,47   65,75   A
--   12 Armario 2 portas          10.394,28   8,59   74,34   A
--    8 Papel A4 500 folhas        9.029,70   7,46   81,80   B
--   14 Cadeira fixa               8.811,00   7,28   89,08   B
--    4 Webcam Full HD             2.822,84   2,33   91,42   B
--    7 HD externo 1 TB            2.244,00   1,85   93,27   B
--    6 Pen drive 64 GB            1.963,95   1,62   94,89   B
--    9 Caneta esferografica...    1.892,16   1,56   96,46   C
--    1 Mouse optico USB           1.843,18   1,52   97,98   C
--    2 Teclado ABNT2              1.543,20   1,28   99,26   C
--   10 Grampeador 26/6              900,25   0,74  100,00   C
--   15 Hub USB 4 portas               0,00   0,00  100,00   C   (sem venda)
WITH vendas AS (
    SELECT pr.id_produto,
           pr.nome,
           NVL(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)), 0) AS valor
      FROM produtos pr
      LEFT JOIN itens_pedido i ON i.id_produto = pr.id_produto
                              AND i.id_pedido IN (SELECT id_pedido FROM pedidos WHERE status <> 'CANCELADO')
     GROUP BY pr.id_produto, pr.nome
),
curva AS (
    SELECT id_produto,
           nome,
           valor,
           100 * valor / SUM(valor) OVER () AS pct,
           100 * SUM(valor) OVER (ORDER BY valor DESC, id_produto ROWS UNBOUNDED PRECEDING)
               / SUM(valor) OVER () AS acumulado
      FROM vendas
)
SELECT LPAD(id_produto, 2) || ' ' || nome AS produto,
       valor,
       ROUND(pct, 2)       AS pct,
       ROUND(acumulado, 2) AS acumulado,
       CASE
           WHEN valor = 0          THEN 'C'
           WHEN acumulado <= 80    THEN 'A'
           WHEN acumulado <= 95    THEN 'B'
           ELSE 'C'
       END AS classe
  FROM curva
 ORDER BY valor DESC, id_produto;

-- 2. Resumo por classe.
-- Esperado: A 5 produtos 89.967,15 (74,3%) | B 5 produtos 24.871,49 (20,6%) |
--           C 5 produtos 6.178,79 (5,1%)
WITH vendas AS (
    SELECT pr.id_produto,
           NVL(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)), 0) AS valor
      FROM produtos pr
      LEFT JOIN itens_pedido i ON i.id_produto = pr.id_produto
                              AND i.id_pedido IN (SELECT id_pedido FROM pedidos WHERE status <> 'CANCELADO')
     GROUP BY pr.id_produto
),
curva AS (
    SELECT valor,
           100 * SUM(valor) OVER (ORDER BY valor DESC, id_produto ROWS UNBOUNDED PRECEDING)
               / SUM(valor) OVER () AS acumulado
      FROM vendas
),
classes AS (
    SELECT valor,
           CASE WHEN valor = 0 THEN 'C' WHEN acumulado <= 80 THEN 'A' WHEN acumulado <= 95 THEN 'B' ELSE 'C' END AS classe
      FROM curva
)
SELECT classe,
       COUNT(*) AS produtos,
       SUM(valor) AS valor,
       ROUND(100 * RATIO_TO_REPORT(SUM(valor)) OVER (), 1) AS pct
  FROM classes
 GROUP BY classe
 ORDER BY classe;

-- 3. O outro critério de corte: o produto que cruza a faixa entra na classe de cima.
-- Esperado: o produto 8 (acumulado antes dele 74,34%) passa de B para A, e o 9
--           (antes dele 94,89%) passa de C para B. Os demais não mudam.
WITH vendas AS (
    SELECT pr.id_produto,
           NVL(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)), 0) AS valor
      FROM produtos pr
      LEFT JOIN itens_pedido i ON i.id_produto = pr.id_produto
                              AND i.id_pedido IN (SELECT id_pedido FROM pedidos WHERE status <> 'CANCELADO')
     GROUP BY pr.id_produto
),
curva AS (
    SELECT id_produto,
           valor,
           100 * SUM(valor) OVER (ORDER BY valor DESC, id_produto ROWS UNBOUNDED PRECEDING) / SUM(valor) OVER () AS acum_depois,
           100 * (SUM(valor) OVER (ORDER BY valor DESC, id_produto ROWS UNBOUNDED PRECEDING) - valor) / SUM(valor) OVER () AS acum_antes
      FROM vendas
)
SELECT id_produto,
       ROUND(acum_antes, 2)  AS acum_antes,
       ROUND(acum_depois, 2) AS acum_depois,
       CASE WHEN valor = 0 THEN 'C' WHEN acum_depois <= 80 THEN 'A' WHEN acum_depois <= 95 THEN 'B' ELSE 'C' END AS classe_depois,
       CASE WHEN valor = 0 THEN 'C' WHEN acum_antes  <  80 THEN 'A' WHEN acum_antes  <  95 THEN 'B' ELSE 'C' END AS classe_antes
  FROM curva
 ORDER BY valor DESC, id_produto;
