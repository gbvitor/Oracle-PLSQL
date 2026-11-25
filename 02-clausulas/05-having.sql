-- =============================================================================
-- Tópico : HAVING — filtro sobre grupos
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Clientes com 3 ou mais pedidos.
-- Esperado: 1 (4), 2, 3, 6 e 10 (3 cada)
SELECT id_cliente, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY id_cliente
HAVING COUNT(*) >= 3
 ORDER BY pedidos DESC, id_cliente;

-- 2. Vendedores com mais de 20 mil vendidos (sem cancelados).
-- Esperado: 108 = 60081.58 e 106 = 30501.92
SELECT p.id_vendedor,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
   AND p.id_vendedor IS NOT NULL
 GROUP BY p.id_vendedor
HAVING SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) > 20000
 ORDER BY valor DESC;

-- 3. Agregação no HAVING que não está no SELECT:
--    pedidos com 3 ou mais produtos diferentes.
-- Esperado: 1001, 1002, 1003, 1008, 1011, 1012, 1013, 1020
SELECT id_pedido
  FROM itens_pedido
 GROUP BY id_pedido
HAVING COUNT(DISTINCT id_produto) >= 3
 ORDER BY id_pedido;

-- 4. Condição sobre o grupo versus sobre a linha.
--    Clientes cujo PRIMEIRO pedido válido foi a partir de junho de 2025.
-- Esperado: 5, 7, 8, 9
SELECT id_cliente, MIN(data_pedido) AS primeiro_pedido
  FROM pedidos
 WHERE status <> 'CANCELADO'
 GROUP BY id_cliente
HAVING MIN(data_pedido) >= DATE '2025-06-01'
 ORDER BY id_cliente;

--    Clientes que fizeram ALGUM pedido a partir de junho de 2025: outra pergunta.
-- Esperado: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
SELECT id_cliente
  FROM pedidos
 WHERE status <> 'CANCELADO'
   AND data_pedido >= DATE '2025-06-01'
 GROUP BY id_cliente
 ORDER BY id_cliente;

-- 5. HAVING sem GROUP BY: a tabela inteira é um grupo.
-- Esperado: nenhuma linha
SELECT COUNT(*) AS pedidos
  FROM pedidos
HAVING COUNT(*) > 100;

-- Esperado: uma linha, 24
SELECT COUNT(*) AS pedidos
  FROM pedidos
HAVING COUNT(*) > 10;

-- 6. Alias do SELECT não vale no HAVING (19c).
-- Esperado no 19c: ORA-00904 ("PEDIDOS": identificador inválido)
SELECT id_cliente, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY id_cliente
HAVING pedidos >= 3;
