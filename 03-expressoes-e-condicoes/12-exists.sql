-- =============================================================================
-- Tópico : EXISTS e NOT EXISTS
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Clientes com pedido em 2026.
-- Esperado: 8 clientes (1, 2, 3, 4, 6, 8, 9, 10)
SELECT c.id_cliente, c.nome
  FROM clientes c
 WHERE EXISTS (SELECT 1
                 FROM pedidos p
                WHERE p.id_cliente  = c.id_cliente
                  AND p.data_pedido >= DATE '2026-01-01')
 ORDER BY c.id_cliente;

-- 2. Clientes sem nenhum pedido.
-- Esperado: 11 e 12
SELECT c.id_cliente, c.nome
  FROM clientes c
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente);

-- 3. Produtos nunca vendidos.
-- Esperado: 15 (Hub USB 4 portas)
SELECT pr.id_produto, pr.nome
  FROM produtos pr
 WHERE NOT EXISTS (SELECT 1 FROM itens_pedido i WHERE i.id_produto = pr.id_produto);

-- 4. Categorias sem produto diretamente ligado (as raízes).
-- Esperado: 1 Informatica e 4 Escritorio
SELECT c.id_categoria, c.nome
  FROM categorias c
 WHERE NOT EXISTS (SELECT 1 FROM produtos p WHERE p.id_categoria = c.id_categoria)
 ORDER BY c.id_categoria;

-- 5. O conteúdo do SELECT da subquery não importa.
-- Esperado: 10 | 10 | 10
SELECT (SELECT COUNT(*) FROM clientes c
         WHERE EXISTS (SELECT 1    FROM pedidos p WHERE p.id_cliente = c.id_cliente)) AS com_1,
       (SELECT COUNT(*) FROM clientes c
         WHERE EXISTS (SELECT *    FROM pedidos p WHERE p.id_cliente = c.id_cliente)) AS com_asterisco,
       (SELECT COUNT(*) FROM clientes c
         WHERE EXISTS (SELECT NULL FROM pedidos p WHERE p.id_cliente = c.id_cliente)) AS com_null
  FROM dual;

-- 6. EXISTS não multiplica linhas; JOIN multiplica.
-- Esperado: 10 | 24
SELECT (SELECT COUNT(*) FROM clientes c
         WHERE EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente)) AS com_exists,
       (SELECT COUNT(*) FROM clientes c
          JOIN pedidos p ON p.id_cliente = c.id_cliente)                           AS com_join
  FROM dual;

-- 7. Três formas de "não tem": NOT EXISTS, outer join + IS NULL, NOT IN.
-- Esperado: 11 e 12 nas três (pedidos.id_cliente é NOT NULL, então o NOT IN
--           funciona aqui; com coluna que aceita nulo, não funcionaria)
SELECT c.id_cliente FROM clientes c
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente)
 ORDER BY 1;

SELECT c.id_cliente
  FROM clientes c
  LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
 WHERE p.id_pedido IS NULL
 ORDER BY 1;

SELECT c.id_cliente FROM clientes c
 WHERE c.id_cliente NOT IN (SELECT p.id_cliente FROM pedidos p)
 ORDER BY 1;

-- 8. O plano mostra o anti-join (HASH JOIN ANTI ou NESTED LOOPS ANTI).
EXPLAIN PLAN FOR
SELECT c.id_cliente FROM clientes c
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 9. Subquery sem correlação: tudo ou nada.
-- Esperado: 12 (existe algum pedido aberto, então todos os clientes passam)
SELECT COUNT(*) AS sem_correlacao
  FROM clientes c
 WHERE EXISTS (SELECT 1 FROM pedidos p WHERE p.status = 'ABERTO');
