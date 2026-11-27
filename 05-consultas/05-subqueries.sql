-- =============================================================================
-- Tópico : Subqueries — tipos, correlação, várias colunas, HAVING, DML
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. De uma linha: o pedido com a data mais recente.
-- Esperado: 1024
SELECT id_pedido, data_pedido
  FROM pedidos
 WHERE data_pedido = (SELECT MAX(data_pedido) FROM pedidos);

-- 2. De várias linhas: clientes de UFs onde existe pedido em aberto.
-- Esperado: os pedidos abertos são de clientes de SP e TO, então 1, 2, 6, 9
SELECT id_cliente, nome, uf
  FROM clientes
 WHERE uf IN (SELECT c.uf
                FROM pedidos  p
                JOIN clientes c ON c.id_cliente = p.id_cliente
               WHERE p.status = 'ABERTO')
 ORDER BY id_cliente;

-- 3. Correlacionada: produtos mais caros que a média da própria categoria.
-- Esperado: 3, 5, 7, 9, 12, 13
SELECT p.id_produto, p.nome, p.id_categoria, p.preco_unitario
  FROM produtos p
 WHERE p.preco_unitario > (SELECT AVG(p2.preco_unitario)
                             FROM produtos p2
                            WHERE p2.id_categoria = p.id_categoria)
 ORDER BY p.id_categoria, p.id_produto;

-- 4. Várias colunas: último pedido de cada cliente.
-- Esperado: 10 linhas (1 -> 1022, 2 -> 1021, 3 -> 1017, ..., 10 -> 1020)
SELECT id_cliente, id_pedido, data_pedido
  FROM pedidos
 WHERE (id_cliente, data_pedido) IN (SELECT id_cliente, MAX(data_pedido)
                                       FROM pedidos
                                      GROUP BY id_cliente)
 ORDER BY id_cliente;

-- 5. No HAVING: categorias acima da média das categorias.
--    Média por categoria: 24203.49
-- Esperado: 2 (24454.42) e 7 (45108.04)
SELECT pr.id_categoria,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS total
  FROM itens_pedido i
  JOIN produtos     pr ON pr.id_produto = i.id_produto
  JOIN pedidos      p  ON p.id_pedido   = i.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY pr.id_categoria
HAVING SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) >
       (SELECT AVG(total_cat)
          FROM (SELECT SUM(ROUND(i2.quantidade * i2.preco_unitario * (1 - i2.pct_desconto / 100), 2)) AS total_cat
                  FROM itens_pedido i2
                  JOIN produtos     pr2 ON pr2.id_produto = i2.id_produto
                  JOIN pedidos      p2  ON p2.id_pedido   = i2.id_pedido
                 WHERE p2.status <> 'CANCELADO'
                 GROUP BY pr2.id_categoria))
 ORDER BY pr.id_categoria;

-- 6. Subquery em DELETE: apagar os itens dos pedidos cancelados.
-- Esperado: 1 linha apagada (o item do pedido 1007)
DELETE FROM itens_pedido
 WHERE id_pedido IN (SELECT id_pedido FROM pedidos WHERE status = 'CANCELADO');

ROLLBACK;

-- 7. A armadilha da coluna que "vaza" para a consulta de fora.
--    produtos não tem id_cliente: o Oracle usa clientes.id_cliente, e a
--    condição vira "id_cliente IN (id_cliente, id_cliente, ...)".
-- Esperado: 12 (todos os clientes, sem erro)
SELECT COUNT(*) AS sem_alias
  FROM clientes
 WHERE id_cliente IN (SELECT id_cliente FROM produtos);

-- Com alias na subquery, o erro aparece.
-- Esperado: ORA-00904 ("PR"."ID_CLIENTE": identificador inválido)
SELECT COUNT(*) AS com_alias
  FROM clientes c
 WHERE c.id_cliente IN (SELECT pr.id_cliente FROM produtos pr);

-- 8. Plano: a subquery IN costuma virar semi-join (HASH JOIN SEMI ou
--    NESTED LOOPS SEMI), igual ao EXISTS.
EXPLAIN PLAN FOR
SELECT c.nome FROM clientes c
 WHERE c.id_cliente IN (SELECT p.id_cliente FROM pedidos p WHERE p.status = 'ABERTO');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
