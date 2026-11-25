-- =============================================================================
-- Tópico : FETCH FIRST / OFFSET — top-N e paginação
-- Seção  : 02-clausulas
-- Versão : 19c (sintaxe disponível desde o 12c)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- Base dos exemplos 1 a 3: quantidade total vendida por produto.
--   8 Papel A4 ............ 305
--   13 Cadeira giratoria ..  53  (empate)
--   5 SSD 480 GB ..........  53  (empate)
--   1 Mouse optico USB ....  49

-- 1. Top-N simples.
-- Esperado: 2 linhas; a segunda pode ser o produto 13 ou o 5 (empate)
SELECT p.id_produto, p.nome, SUM(i.quantidade) AS qtd_vendida
  FROM itens_pedido i
  JOIN produtos     p ON p.id_produto = i.id_produto
 GROUP BY p.id_produto, p.nome
 ORDER BY qtd_vendida DESC
 FETCH FIRST 2 ROWS ONLY;

-- 2. WITH TIES: inclui quem empata com a última linha.
-- Esperado: 3 linhas (8, 13 e 5)
SELECT p.id_produto, p.nome, SUM(i.quantidade) AS qtd_vendida
  FROM itens_pedido i
  JOIN produtos     p ON p.id_produto = i.id_produto
 GROUP BY p.id_produto, p.nome
 ORDER BY qtd_vendida DESC
 FETCH FIRST 2 ROWS WITH TIES;

-- 3. Desempate explícito: resultado estável.
-- Esperado: 8 e 5
SELECT p.id_produto, p.nome, SUM(i.quantidade) AS qtd_vendida
  FROM itens_pedido i
  JOIN produtos     p ON p.id_produto = i.id_produto
 GROUP BY p.id_produto, p.nome
 ORDER BY qtd_vendida DESC, p.id_produto
 FETCH FIRST 2 ROWS ONLY;

-- 4. Percentual: 10% de 24 pedidos = 2,4, arredondado para cima.
-- Esperado: 3 linhas
SELECT id_pedido, data_pedido
  FROM pedidos
 ORDER BY data_pedido DESC
 FETCH FIRST 10 PERCENT ROWS ONLY;

-- 5. Paginação com OFFSET: página 2, 5 por página.
-- Esperado: 1006 a 1010
SELECT id_pedido, data_pedido, status
  FROM pedidos
 ORDER BY id_pedido
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;

-- 6. Paginação por chave: próxima página depois do último id visto (1010).
-- Esperado: 1011 a 1015
SELECT id_pedido, data_pedido, status
  FROM pedidos
 WHERE id_pedido > 1010
 ORDER BY id_pedido
 FETCH FIRST 5 ROWS ONLY;

-- 7. O mesmo top-N e a mesma página com ROWNUM (padrão anterior ao 12c).
-- Esperado: igual ao exemplo 3
SELECT *
  FROM (SELECT p.id_produto, p.nome, SUM(i.quantidade) AS qtd_vendida
          FROM itens_pedido i
          JOIN produtos     p ON p.id_produto = i.id_produto
         GROUP BY p.id_produto, p.nome
         ORDER BY qtd_vendida DESC, p.id_produto)
 WHERE ROWNUM <= 2;

-- Esperado: igual ao exemplo 5
SELECT id_pedido, data_pedido, status
  FROM (SELECT v.*, ROWNUM AS rn
          FROM (SELECT id_pedido, data_pedido, status
                  FROM pedidos
                 ORDER BY id_pedido) v
         WHERE ROWNUM <= 10)
 WHERE rn > 5;

-- 8. Como o Oracle executa o FETCH FIRST: o plano mostra WINDOW e
--    o filtro sobre ROW_NUMBER.
EXPLAIN PLAN FOR
SELECT id_pedido FROM pedidos ORDER BY data_pedido DESC FETCH FIRST 3 ROWS ONLY;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));
