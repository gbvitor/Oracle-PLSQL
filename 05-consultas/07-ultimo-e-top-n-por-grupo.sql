-- =============================================================================
-- Tópico : Último registro e top-N por grupo — formas comparadas
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Todas as formas de 1 a 5 respondem: último pedido de cada cliente.
-- Esperado em todas: 10 linhas
--   1 -> 1022 | 2 -> 1021 | 3 -> 1017 | 4 -> 1019 | 5 -> 1010
--   6 -> 1024 | 7 -> 1016 | 8 -> 1018 | 9 -> 1023 | 10 -> 1020
-- =============================================================================

-- 1. ROW_NUMBER em inline view (padrão recomendado).
SELECT id_cliente, id_pedido, data_pedido
  FROM (SELECT id_cliente, id_pedido, data_pedido,
               ROW_NUMBER() OVER (PARTITION BY id_cliente
                                  ORDER BY data_pedido DESC, id_pedido DESC) AS rn
          FROM pedidos)
 WHERE rn = 1
 ORDER BY id_cliente;

-- 2. Subquery de várias colunas com MAX.
SELECT id_cliente, id_pedido, data_pedido
  FROM pedidos
 WHERE (id_cliente, data_pedido) IN (SELECT id_cliente, MAX(data_pedido)
                                       FROM pedidos
                                      GROUP BY id_cliente)
 ORDER BY id_cliente;

-- 3. NOT EXISTS de um pedido posterior do mesmo cliente.
SELECT p.id_cliente, p.id_pedido, p.data_pedido
  FROM pedidos p
 WHERE NOT EXISTS (SELECT 1
                     FROM pedidos p2
                    WHERE p2.id_cliente  = p.id_cliente
                      AND p2.data_pedido > p.data_pedido)
 ORDER BY p.id_cliente;

-- 4. KEEP numa agregação (junto de outras métricas do cliente).
SELECT id_cliente,
       MAX(id_pedido)   KEEP (DENSE_RANK LAST ORDER BY data_pedido) AS id_pedido,
       MAX(data_pedido)                                            AS data_pedido,
       COUNT(*)                                                    AS total_pedidos
  FROM pedidos
 GROUP BY id_cliente
 ORDER BY id_cliente;

-- 5. LATERAL com FETCH FIRST.
SELECT c.id_cliente, u.id_pedido, u.data_pedido
  FROM clientes c
 CROSS APPLY (SELECT p.id_pedido, p.data_pedido
                FROM pedidos p
               WHERE p.id_cliente = c.id_cliente
               ORDER BY p.data_pedido DESC, p.id_pedido DESC
               FETCH FIRST 1 ROW ONLY) u
 ORDER BY c.id_cliente;

-- 6. Empate: com duas linhas na mesma data máxima, as formas divergem.
--    Cópia dos pedidos com um empate proposital no cliente 1.
CREATE TABLE tmp_pedidos AS SELECT id_pedido, id_cliente, data_pedido FROM pedidos;
INSERT INTO tmp_pedidos VALUES (2001, 1, (SELECT data_pedido FROM pedidos WHERE id_pedido = 1022));
COMMIT;

-- Esperado: ROW_NUMBER -> 1 linha para o cliente 1 (2001, pelo desempate em id DESC)
--           RANK       -> 2 linhas (1022 e 2001)
--           MAX/IN     -> 2 linhas
SELECT 'row_number' AS forma, id_cliente, id_pedido
  FROM (SELECT t.*, ROW_NUMBER() OVER (PARTITION BY id_cliente
                                       ORDER BY data_pedido DESC, id_pedido DESC) AS n
          FROM tmp_pedidos t)
 WHERE n = 1 AND id_cliente = 1
UNION ALL
SELECT 'rank', id_cliente, id_pedido
  FROM (SELECT t.*, RANK() OVER (PARTITION BY id_cliente ORDER BY data_pedido DESC) AS n
          FROM tmp_pedidos t)
 WHERE n = 1 AND id_cliente = 1
UNION ALL
SELECT 'max_in', id_cliente, id_pedido
  FROM tmp_pedidos
 WHERE id_cliente = 1
   AND (id_cliente, data_pedido) IN (SELECT id_cliente, MAX(data_pedido) FROM tmp_pedidos GROUP BY id_cliente)
 ORDER BY 1, 3;

DROP TABLE tmp_pedidos PURGE;

-- 7. Top-N com N > 1: os dois maiores pedidos de cada vendedor.
-- Esperado:
--   104: 1021 (4076.64), 1013 (2609.31)   | 105: 1011 (6019.15), 1003 (3945.03)
--   106: 1002 (16276.50), 1017 (7554.28)  | 107: 1015 (1311.50), 1016 (988.90)
--   108: 1008 (27286.00), 1020 (16832.88)
WITH valor_pedido AS (
    SELECT p.id_vendedor, p.id_pedido,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
       AND p.id_vendedor IS NOT NULL
     GROUP BY p.id_vendedor, p.id_pedido
)
SELECT id_vendedor, id_pedido, valor
  FROM (SELECT v.*,
               ROW_NUMBER() OVER (PARTITION BY id_vendedor ORDER BY valor DESC, id_pedido) AS rn
          FROM valor_pedido v)
 WHERE rn <= 2
 ORDER BY id_vendedor, rn;

-- 8. Vigência: preço válido de cada produto numa data.
--    Tabela de histórico de preços de teste.
CREATE TABLE tmp_precos (
    id_produto       NUMBER,
    inicio_vigencia  DATE,
    preco            NUMBER(10,2)
);
INSERT INTO tmp_precos VALUES (1, DATE '2025-01-01', 35.90);
INSERT INTO tmp_precos VALUES (1, DATE '2025-07-01', 37.90);
INSERT INTO tmp_precos VALUES (1, DATE '2026-01-01', 39.90);
INSERT INTO tmp_precos VALUES (2, DATE '2025-01-01', 84.90);
INSERT INTO tmp_precos VALUES (2, DATE '2026-03-01', 89.90);
COMMIT;

-- Preço vigente em 30/06/2025.
-- Esperado: produto 1 -> 35.90 | produto 2 -> 84.90
SELECT id_produto, inicio_vigencia, preco
  FROM (SELECT t.*,
               ROW_NUMBER() OVER (PARTITION BY id_produto ORDER BY inicio_vigencia DESC) AS rn
          FROM tmp_precos t
         WHERE inicio_vigencia <= DATE '2025-06-30')
 WHERE rn = 1
 ORDER BY id_produto;

-- Preço vigente na data de cada item vendido (join com vigência).
-- Esperado: 1003 produto 1 -> 35.90 | 1011 produto 1 -> 37.90 | 1021 produto 1 -> 39.90
SELECT i.id_pedido, i.id_produto, p.data_pedido, i.preco_unitario AS praticado,
       (SELECT MAX(t.preco) KEEP (DENSE_RANK LAST ORDER BY t.inicio_vigencia)
          FROM tmp_precos t
         WHERE t.id_produto       = i.id_produto
           AND t.inicio_vigencia <= p.data_pedido) AS vigente
  FROM itens_pedido i
  JOIN pedidos      p ON p.id_pedido = i.id_pedido
 WHERE i.id_produto IN (1, 2)
 ORDER BY i.id_produto, p.data_pedido;

DROP TABLE tmp_precos PURGE;
