-- =============================================================================
-- Tópico : Funções analíticas II — LAG, LEAD, FIRST_VALUE, LAST_VALUE, KEEP
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Vendas por mês com o mês anterior e a variação.
--    Atenção: 2025-04, 2026-03, 2026-05 e 2026-07 não têm venda; o LAG de
--    2025-05 é 2025-03 (linha anterior), não abril.
-- Esperado (primeiras linhas):
--   2025-01 17322.00 | anterior nulo
--   2025-02  5706.83 | anterior 17322.00 | variação -11615.17
--   2025-03  2185.70 | anterior  5706.83 | variação  -3521.13
--   2025-05 32449.44 | anterior  2185.70 | variação  30263.74
WITH mensal AS (
    SELECT TO_CHAR(p.data_pedido, 'YYYY-MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TO_CHAR(p.data_pedido, 'YYYY-MM')
)
SELECT mes,
       valor,
       LAG(valor)          OVER (ORDER BY mes) AS anterior,
       valor - LAG(valor)  OVER (ORDER BY mes) AS variacao,
       LEAD(mes)           OVER (ORDER BY mes) AS proximo_mes_com_venda
  FROM mensal
 ORDER BY mes;

-- 2. Comparar com o mês calendário anterior: gerar todos os meses antes.
-- Esperado: 22 meses (jan/2025 a out/2026); 2025-05 com anterior = 0 (abril sem venda)
WITH meses AS (
    SELECT TO_CHAR(ADD_MONTHS(DATE '2025-01-01', LEVEL - 1), 'YYYY-MM') AS mes
      FROM dual
   CONNECT BY LEVEL <= 22
),
mensal AS (
    SELECT TO_CHAR(p.data_pedido, 'YYYY-MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TO_CHAR(p.data_pedido, 'YYYY-MM')
)
SELECT m.mes,
       NVL(v.valor, 0)                                 AS valor,
       LAG(NVL(v.valor, 0)) OVER (ORDER BY m.mes)      AS mes_anterior
  FROM meses  m
  LEFT JOIN mensal v ON v.mes = m.mes
 ORDER BY m.mes;

-- 3. Dias desde o pedido anterior e até o próximo, por cliente.
SELECT id_cliente,
       id_pedido,
       TO_CHAR(data_pedido, 'YYYY-MM-DD') AS data,
       ROUND(data_pedido - LAG(data_pedido)  OVER (PARTITION BY id_cliente ORDER BY data_pedido)) AS dias_desde_anterior,
       ROUND(LEAD(data_pedido) OVER (PARTITION BY id_cliente ORDER BY data_pedido) - data_pedido) AS dias_ate_proximo
  FROM pedidos
 WHERE id_cliente IN (1, 3)
 ORDER BY id_cliente, data_pedido;

-- 4. Mudança de status entre pedidos consecutivos do mesmo cliente,
--    com valor padrão no LAG para o primeiro pedido.
SELECT id_cliente, id_pedido, status,
       LAG(status, 1, '(primeiro)') OVER (PARTITION BY id_cliente ORDER BY data_pedido) AS status_anterior
  FROM pedidos
 WHERE id_cliente = 8;
-- Esperado: 1007 CANCELADO (primeiro) | 1018 ENTREGUE (anterior CANCELADO)

-- 5. FIRST_VALUE e a armadilha do LAST_VALUE.
--    Para cada pedido do cliente 1: o primeiro e o último pedido do cliente.
-- Esperado: primeiro = 1001 em todas as linhas
--           ultimo_errado = o próprio pedido da linha
--           ultimo_certo  = 1022 em todas as linhas
SELECT id_pedido,
       FIRST_VALUE(id_pedido) OVER (ORDER BY data_pedido)                AS primeiro,
       LAST_VALUE(id_pedido)  OVER (ORDER BY data_pedido)                AS ultimo_errado,
       LAST_VALUE(id_pedido)  OVER (ORDER BY data_pedido
                                    ROWS BETWEEN UNBOUNDED PRECEDING
                                             AND UNBOUNDED FOLLOWING)    AS ultimo_certo,
       FIRST_VALUE(id_pedido) OVER (ORDER BY data_pedido DESC)           AS ultimo_alternativa
  FROM pedidos
 WHERE id_cliente = 1
 ORDER BY data_pedido;

-- 6. NTH_VALUE: o segundo pedido de cada cliente.
-- Esperado: cliente 1 -> 1006 | 2 -> 1011 | 3 -> 1009 | clientes com 1 pedido -> nulo
SELECT DISTINCT id_cliente,
       NTH_VALUE(id_pedido, 2) OVER (PARTITION BY id_cliente ORDER BY data_pedido
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS segundo_pedido
  FROM pedidos
 ORDER BY id_cliente;

-- 7. IGNORE NULLS: último vendedor conhecido até cada pedido do cliente 6.
--    O pedido 1024 foi pelo site (vendedor nulo).
-- Esperado: 1004 104 | 1013 104 | 1024 vendedor nulo, ultimo_conhecido 104
SELECT id_pedido,
       id_vendedor,
       LAST_VALUE(id_vendedor IGNORE NULLS) OVER (ORDER BY data_pedido) AS ultimo_conhecido
  FROM pedidos
 WHERE id_cliente = 6
 ORDER BY data_pedido;

-- 8. KEEP como analítica: em cada linha, o produto mais caro do pedido.
SELECT id_pedido, nr_item, id_produto, preco_unitario,
       MAX(id_produto) KEEP (DENSE_RANK LAST ORDER BY preco_unitario)
           OVER (PARTITION BY id_pedido) AS produto_mais_caro_do_pedido
  FROM itens_pedido
 WHERE id_pedido IN (1002, 1008)
 ORDER BY id_pedido, nr_item;
-- Esperado: 1002 -> produto 3 (849.00) | 1008 -> produto 12 (870.00)
