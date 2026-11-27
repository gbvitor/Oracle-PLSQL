-- =============================================================================
-- Tópico : INNER JOIN — igualdade, várias tabelas, desigualdade, granularidade
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Join simples: pedido com o nome do cliente.
-- Esperado: 24 linhas
SELECT p.id_pedido, p.data_pedido, c.nome AS cliente
  FROM pedidos  p
  JOIN clientes c ON c.id_cliente = p.id_cliente
 ORDER BY p.id_pedido;

-- 2. Inner join com FK nula perde linhas.
--    3 pedidos foram feitos pelo site (id_vendedor nulo).
-- Esperado: 21 (não 24)
SELECT COUNT(*) AS pedidos_com_vendedor
  FROM pedidos      p
  JOIN funcionarios f ON f.id_funcionario = p.id_vendedor;

-- 3. Várias tabelas: item -> pedido -> cliente; item -> produto -> categoria.
SELECT p.id_pedido,
       c.nome          AS cliente,
       i.nr_item,
       pr.nome         AS produto,
       cat.nome        AS categoria,
       i.quantidade,
       i.preco_unitario
  FROM itens_pedido i
  JOIN pedidos      p   ON p.id_pedido     = i.id_pedido
  JOIN clientes     c   ON c.id_cliente    = p.id_cliente
  JOIN produtos     pr  ON pr.id_produto   = i.id_produto
  JOIN categorias   cat ON cat.id_categoria = pr.id_categoria
 WHERE p.id_pedido = 1008
 ORDER BY i.nr_item;

-- 4. Join por desigualdade: faixa de desconto de cada item.
--    A tabela de faixas é montada com WITH; poderia ser uma tabela real.
-- Esperado: Sem desconto 25 | Ate 5% 12 | De 5 a 10% 15 | Acima de 10% 2
WITH faixas AS (
    SELECT 1 AS ordem, 'Sem desconto' AS faixa, 0     AS minimo, 0   AS maximo FROM dual UNION ALL
    SELECT 2,          'Ate 5%',               0.01,            5            FROM dual UNION ALL
    SELECT 3,          'De 5 a 10%',           5.01,            10           FROM dual UNION ALL
    SELECT 4,          'Acima de 10%',         10.01,           100          FROM dual
)
SELECT f.faixa, COUNT(*) AS itens
  FROM itens_pedido i
  JOIN faixas       f ON i.pct_desconto BETWEEN f.minimo AND f.maximo
 GROUP BY f.ordem, f.faixa
 ORDER BY f.ordem;

-- 5. Condição na chave composta e condição extra no ON.
--    Itens vendidos pelo preço de tabela atual.
-- Esperado: 27
SELECT COUNT(*) AS itens_no_preco_de_tabela
  FROM itens_pedido i
  JOIN produtos     p ON p.id_produto     = i.id_produto
                     AND p.preco_unitario = i.preco_unitario;

-- 6. Granularidade: somar uma coluna do pedido depois do join com itens.
--    Cada pedido aparece uma vez por item, e a soma multiplica.
--    Exemplo com a quantidade de pedidos por cliente:
-- Esperado: cliente 1 -> 9 com join (itens) | 4 contando pedidos distintos
SELECT p.id_cliente,
       COUNT(*)                    AS linhas_apos_join,
       COUNT(DISTINCT p.id_pedido) AS pedidos
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.id_cliente = 1
 GROUP BY p.id_cliente;

-- 7. A ordem das tabelas não muda o resultado do inner join.
-- Esperado: 24 | 24
SELECT (SELECT COUNT(*) FROM pedidos p JOIN clientes c ON c.id_cliente = p.id_cliente) AS pedidos_clientes,
       (SELECT COUNT(*) FROM clientes c JOIN pedidos p ON p.id_cliente = c.id_cliente) AS clientes_pedidos
  FROM dual;
