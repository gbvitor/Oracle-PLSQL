-- =============================================================================
-- Tópico : GROUP BY, ROLLUP, CUBE, GROUPING SETS, GROUPING
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Valor líquido do item = quantidade * preco_unitario * (1 - pct_desconto / 100),
-- arredondado a 2 casas. Pedidos cancelados ficam fora dos valores.
-- =============================================================================

-- 1. Uma linha por grupo.
-- Esperado: ABERTO 3, CANCELADO 1, ENTREGUE 17, FATURADO 3
SELECT status, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY status
 ORDER BY status;

-- 2. Coluna fora do GROUP BY e fora de agregação.
-- Esperado: ORA-00979 (não é uma expressão GROUP BY)
SELECT id_cliente, status, COUNT(*)
  FROM pedidos
 GROUP BY id_cliente;

-- 3. Mais de uma coluna e agrupamento por expressão.
-- Esperado: 2025 CANCELADO 1, 2025 ENTREGUE 15, 2026 ABERTO 3, 2026 ENTREGUE 2, 2026 FATURADO 3
SELECT EXTRACT(YEAR FROM data_pedido) AS ano, status, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY EXTRACT(YEAR FROM data_pedido), status
 ORDER BY ano, status;

-- 4. Granularidade: depois do join com itens, COUNT(*) conta itens.
-- Esperado: itens 54 | pedidos 24
SELECT COUNT(*)                    AS itens,
       COUNT(DISTINCT p.id_pedido) AS pedidos
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido;

-- 5. Valor vendido por ano.
-- Esperado: 2025 = 85314.23, 2026 = 35703.20
SELECT EXTRACT(YEAR FROM p.data_pedido) AS ano,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY EXTRACT(YEAR FROM p.data_pedido)
 ORDER BY ano;

-- 6. ROLLUP: detalhe por UF e ano, subtotal por UF e total geral.
--    GROUPING() distingue NULL de subtotal de NULL de dado.
-- Esperado: 22 linhas; DF subtotal 60081.58; total geral 121017.43
SELECT CASE WHEN GROUPING(c.uf) = 1 THEN 'TOTAL GERAL' ELSE c.uf END AS uf,
       CASE
           WHEN GROUPING(c.uf) = 1                            THEN NULL
           WHEN GROUPING(EXTRACT(YEAR FROM p.data_pedido)) = 1 THEN 'subtotal'
           ELSE TO_CHAR(EXTRACT(YEAR FROM p.data_pedido))
       END AS ano,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos      p
  JOIN clientes     c ON c.id_cliente = p.id_cliente
  JOIN itens_pedido i ON i.id_pedido  = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY ROLLUP(c.uf, EXTRACT(YEAR FROM p.data_pedido))
 ORDER BY GROUPING(c.uf), c.uf, GROUPING(EXTRACT(YEAR FROM p.data_pedido)), 2;

-- 7. CUBE: todas as combinações de ano e status, com totais de cada lado.
-- Esperado: 12 linhas; total por ano 2025 = 16, 2026 = 8; total geral 24
SELECT EXTRACT(YEAR FROM data_pedido) AS ano,
       status,
       COUNT(*)                       AS pedidos,
       GROUPING_ID(EXTRACT(YEAR FROM data_pedido), status) AS nivel
  FROM pedidos
 GROUP BY CUBE(EXTRACT(YEAR FROM data_pedido), status)
 ORDER BY nivel, ano, status;
-- nivel 0 = detalhe; 1 = total do ano; 2 = total do status; 3 = total geral

-- 8. GROUPING SETS: só os níveis pedidos.
--    Contagem de clientes por UF, por tipo de pessoa e total, numa consulta.
-- Esperado: 13 linhas (10 UFs + F 5 + J 7 + total 12)
SELECT CASE
           WHEN GROUPING(uf) = 0          THEN 'UF ' || uf
           WHEN GROUPING(tipo_pessoa) = 0 THEN 'Tipo ' || tipo_pessoa
           ELSE 'Total'
       END       AS grupo,
       COUNT(*)  AS clientes
  FROM clientes
 GROUP BY GROUPING SETS ((uf), (tipo_pessoa), ())
 ORDER BY GROUPING(uf), GROUPING(tipo_pessoa), grupo;

-- 9. Agrupar por mês com TO_CHAR.
-- Esperado: 2026-01 a 2026-10, sete meses com pedido; outubro com 2
SELECT TO_CHAR(data_pedido, 'YYYY-MM') AS competencia, COUNT(*) AS pedidos
  FROM pedidos
 WHERE data_pedido >= DATE '2026-01-01'
 GROUP BY TO_CHAR(data_pedido, 'YYYY-MM')
 ORDER BY competencia;

-- 10. NULL de dado como grupo: pedidos sem vendedor formam um grupo próprio.
SELECT NVL(TO_CHAR(id_vendedor), 'site') AS vendedor, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY id_vendedor
 ORDER BY id_vendedor NULLS LAST;
