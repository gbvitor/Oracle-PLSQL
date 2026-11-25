-- =============================================================================
-- Tópico : PIVOT e UNPIVOT
-- Seção  : 02-clausulas
-- Versão : 19c (disponível desde o 11g)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Quantidade de pedidos por status (linhas) e ano (colunas).
-- Esperado:
--   ABERTO     0  3
--   CANCELADO  1  0
--   ENTREGUE  15  2
--   FATURADO   0  3
SELECT *
  FROM (SELECT status, EXTRACT(YEAR FROM data_pedido) AS ano
          FROM pedidos)
 PIVOT (COUNT(*) FOR ano IN (2025 AS a2025, 2026 AS a2026))
 ORDER BY status;

-- 2. A regra implícita: com a tabela inteira como origem, todas as demais
--    colunas viram agrupamento e sai uma linha por pedido.
-- Esperado: 24 linhas, não 4
SELECT COUNT(*) AS linhas
  FROM (SELECT *
          FROM (SELECT p.*, EXTRACT(YEAR FROM data_pedido) AS ano FROM pedidos p)
         PIVOT (COUNT(*) FOR ano IN (2025 AS a2025, 2026 AS a2026)));

-- 3. Valor vendido por vendedor e ano.
-- Esperado (2025 | 2026):
--   104   7462.61 |  5589.64
--   105  10343.18 |   169.70
--   106  21439.94 |  9061.98
--   107   2300.40 |   899.00
--   108  43248.70 | 16832.88
--   site   519.40 |  3150.00
SELECT *
  FROM (SELECT NVL(TO_CHAR(p.id_vendedor), 'site')                AS vendedor,
               EXTRACT(YEAR FROM p.data_pedido)                    AS ano,
               ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2) AS valor
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO')
 PIVOT (SUM(valor) FOR ano IN (2025 AS a2025, 2026 AS a2026))
 ORDER BY vendedor;

-- 4. Duas agregações: quantidade de itens e valor, por ano.
--    Cada agregação gera um conjunto de colunas: A2025_ITENS, A2025_VALOR...
SELECT *
  FROM (SELECT NVL(TO_CHAR(p.id_vendedor), 'site')                AS vendedor,
               EXTRACT(YEAR FROM p.data_pedido)                    AS ano,
               ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2) AS valor
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO')
 PIVOT (COUNT(*) AS itens, SUM(valor) AS valor
        FOR ano IN (2025 AS a2025, 2026 AS a2026))
 ORDER BY vendedor;

-- 5. O mesmo do exemplo 3 com agregação condicional, mais uma coluna de total.
SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
       SUM(CASE WHEN EXTRACT(YEAR FROM p.data_pedido) = 2025
                THEN ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2) END) AS a2025,
       SUM(CASE WHEN EXTRACT(YEAR FROM p.data_pedido) = 2026
                THEN ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2) END) AS a2026,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2))              AS total
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY p.id_vendedor
 ORDER BY vendedor;

-- 6. UNPIVOT: de volta para linhas.
--    A tabela larga é montada com o PIVOT do exemplo 1.
-- Esperado: 8 linhas (4 status x 2 anos). Os zeros também viram linhas,
--           porque COUNT devolve 0 e não nulo.
WITH larga AS (
    SELECT *
      FROM (SELECT status, EXTRACT(YEAR FROM data_pedido) AS ano FROM pedidos)
     PIVOT (COUNT(*) FOR ano IN (2025 AS a2025, 2026 AS a2026))
)
SELECT status, ano, pedidos
  FROM larga
UNPIVOT (pedidos FOR ano IN (a2025 AS 2025, a2026 AS 2026))
 ORDER BY status, ano;

-- 7. UNPIVOT descarta NULL; INCLUDE NULLS mantém.
WITH larga AS (
    SELECT 'X' AS chave, 10 AS jan, CAST(NULL AS NUMBER) AS fev, 30 AS mar FROM dual
)
SELECT 'padrao' AS modo, mes, valor
  FROM larga
UNPIVOT (valor FOR mes IN (jan AS 'JAN', fev AS 'FEV', mar AS 'MAR'))
UNION ALL
SELECT 'include nulls', mes, valor
  FROM larga
UNPIVOT INCLUDE NULLS (valor FOR mes IN (jan AS 'JAN', fev AS 'FEV', mar AS 'MAR'));
-- padrao: JAN e MAR; include nulls: JAN, FEV (nulo) e MAR
