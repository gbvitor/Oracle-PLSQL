-- =============================================================================
-- Caso   : Vendas por mês com acumulado no ano, mês anterior, variação e
--          mesmo mês do ano anterior; meses sem venda com zero
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
--
-- Vendas = valor líquido dos itens de pedidos não cancelados.
-- Período: janeiro de 2025 a outubro de 2026 (22 meses).
-- =============================================================================

SET LINESIZE 160
SET PAGESIZE 50
COLUMN mes        FORMAT A7
COLUMN valor      FORMAT 999G990D00
COLUMN acumulado  FORMAT 999G990D00
COLUMN anterior   FORMAT 999G990D00
COLUMN ano_ant    FORMAT 999G990D00
COLUMN variacao   FORMAT 99990D0

-- 1. Sem calendário: só os meses que tiveram venda.
-- Esperado: 18 meses (faltam 2025-04, 2026-03, 2026-05 e 2026-07)
SELECT TO_CHAR(TRUNC(p.data_pedido, 'MM'), 'YYYY-MM') AS mes,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY TRUNC(p.data_pedido, 'MM')
 ORDER BY 1;

-- 2. O relatório completo.
-- Esperado (22 linhas):
--   MES          VALOR   ACUMULADO    ANTERIOR  VARIACAO     ANO_ANT
--   2025-01  17.322,00   17.322,00
--   2025-02   5.706,83   23.028,83   17.322,00     -67,1
--   2025-03   2.185,70   25.214,53    5.706,83     -61,7
--   2025-04       0,00   25.214,53    2.185,70    -100,0
--   2025-05  32.449,44   57.663,97        0,00             (variação sem base: vazio)
--   2025-06     379,00   58.042,97   32.449,44     -98,8
--   2025-07   6.019,15   64.062,12      379,00   1.488,2
--   2025-08     379,70   64.441,82    6.019,15     -93,7
--   2025-09   2.609,31   67.051,13      379,70     587,2
--   2025-10  15.962,70   83.013,83    2.609,31     511,8
--   2025-11   1.311,50   84.325,33   15.962,70     -91,8
--   2025-12     988,90   85.314,23    1.311,50     -24,6
--   2026-01   7.554,28    7.554,28      988,90     663,9   17.322,00
--   2026-02   1.507,70    9.061,98    7.554,28     -80,0    5.706,83
--   2026-03       0,00    9.061,98    1.507,70    -100,0    2.185,70
--   2026-04     169,70    9.231,68        0,00                  0,00
--   2026-05       0,00    9.231,68      169,70    -100,0   32.449,44
--   2026-06  16.832,88   26.064,56        0,00                379,00
--   2026-07       0,00   26.064,56   16.832,88    -100,0    6.019,15
--   2026-08   4.076,64   30.141,20        0,00                379,70
--   2026-09   1.513,00   31.654,20    4.076,64     -62,9    2.609,31
--   2026-10   4.049,00   35.703,20    1.513,00     167,6   15.962,70
--   (o acumulado reinicia em janeiro; 85.314,23 é o total de 2025 e 35.703,20 o de 2026)
WITH meses AS (
    SELECT ADD_MONTHS(DATE '2025-01-01', LEVEL - 1) AS mes
      FROM dual
   CONNECT BY LEVEL <= 22
),
vendas AS (
    SELECT TRUNC(p.data_pedido, 'MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TRUNC(p.data_pedido, 'MM')
),
base AS (
    SELECT m.mes, NVL(v.valor, 0) AS valor
      FROM meses m
      LEFT JOIN vendas v ON v.mes = m.mes
)
SELECT TO_CHAR(mes, 'YYYY-MM') AS mes,
       valor,
       SUM(valor) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes) AS acumulado,
       LAG(valor) OVER (ORDER BY mes) AS anterior,
       ROUND((valor - LAG(valor) OVER (ORDER BY mes))
             / NULLIF(LAG(valor) OVER (ORDER BY mes), 0) * 100, 1) AS variacao,
       LAG(valor, 12) OVER (ORDER BY mes) AS ano_ant
  FROM base
 ORDER BY base.mes;

-- 3. O erro de usar LAG(valor, 12) sem calendário.
-- Esperado em 2026-10: ano_ant = 6.019,15 (o valor de 2025-07: doze linhas acima,
--           porque faltam quatro meses na lista), quando o certo é 15.962,70
WITH vendas AS (
    SELECT TRUNC(p.data_pedido, 'MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TRUNC(p.data_pedido, 'MM')
)
SELECT TO_CHAR(mes, 'YYYY-MM') AS mes, valor, LAG(valor, 12) OVER (ORDER BY mes) AS ano_ant
  FROM vendas
 ORDER BY vendas.mes DESC
 FETCH FIRST 1 ROW ONLY;

-- 4. Variante: média móvel de 3 meses e participação de cada mês no ano.
WITH meses AS (
    SELECT ADD_MONTHS(DATE '2025-01-01', LEVEL - 1) AS mes FROM dual CONNECT BY LEVEL <= 12
),
vendas AS (
    SELECT TRUNC(p.data_pedido, 'MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TRUNC(p.data_pedido, 'MM')
)
SELECT TO_CHAR(m.mes, 'YYYY-MM') AS mes,
       NVL(v.valor, 0) AS valor,
       ROUND(AVG(NVL(v.valor, 0)) OVER (ORDER BY m.mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS media_3m,
       ROUND(100 * RATIO_TO_REPORT(NVL(v.valor, 0)) OVER (), 1) AS pct_ano
  FROM meses m
  LEFT JOIN vendas v ON v.mes = m.mes
 ORDER BY m.mes;
-- Esperado: 12 linhas de 2025; pct_ano de maio 38,0 (32.449,44 de 85.314,23);
--           média de março (17.322 + 5.706,83 + 2.185,70) / 3 = 8.404,84
