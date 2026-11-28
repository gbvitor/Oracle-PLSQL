-- =============================================================================
-- Caso   : Clientes sem compra no período, clientes perdidos e a armadilha
--          do NOT IN com NULL
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
--
-- Compra = pedido não cancelado. Data de referência fixa (27/11/2026), para o
-- resultado não depender do dia em que o script roda.
-- =============================================================================

COLUMN nome FORMAT A26

-- 1. Sem compra em 2026: NOT EXISTS.
-- Esperado: 5 Patricia Moura | 7 Rafael Teixeira | 11 Loja Antiga ME | 12 Thiago Nunes
SELECT c.id_cliente, c.nome
  FROM clientes c
 WHERE NOT EXISTS (SELECT 1
                     FROM pedidos p
                    WHERE p.id_cliente = c.id_cliente
                      AND p.status <> 'CANCELADO'
                      AND p.data_pedido >= DATE '2026-01-01'
                      AND p.data_pedido <  DATE '2027-01-01')
 ORDER BY c.id_cliente;

-- 2. O mesmo com LEFT JOIN: o período no ON.
-- Esperado: os mesmos 4
SELECT c.id_cliente, c.nome
  FROM clientes c
  LEFT JOIN pedidos p
    ON p.id_cliente = c.id_cliente
   AND p.status <> 'CANCELADO'
   AND p.data_pedido >= DATE '2026-01-01'
   AND p.data_pedido <  DATE '2027-01-01'
 WHERE p.id_pedido IS NULL
 ORDER BY c.id_cliente;

-- O período no WHERE transforma o LEFT JOIN em INNER JOIN.
-- Esperado: nenhuma linha
SELECT c.id_cliente, c.nome
  FROM clientes c
  LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
 WHERE p.data_pedido >= DATE '2026-01-01'
   AND p.id_pedido IS NULL;

-- 3. Perdidos: compraram em 2025 e não em 2026; com dias desde a última compra.
-- Esperado: 5 Patricia Moura 528 dias | 7 Rafael Teixeira 350 dias
SELECT c.id_cliente,
       c.nome,
       DATE '2026-11-27' - TRUNC(MAX(p.data_pedido)) AS dias_sem_comprar
  FROM clientes c
  JOIN pedidos p ON p.id_cliente = c.id_cliente AND p.status <> 'CANCELADO'
 WHERE EXISTS (SELECT 1 FROM pedidos p1
                WHERE p1.id_cliente = c.id_cliente AND p1.status <> 'CANCELADO'
                  AND p1.data_pedido >= DATE '2025-01-01' AND p1.data_pedido < DATE '2026-01-01')
   AND NOT EXISTS (SELECT 1 FROM pedidos p2
                    WHERE p2.id_cliente = c.id_cliente AND p2.status <> 'CANCELADO'
                      AND p2.data_pedido >= DATE '2026-01-01')
 GROUP BY c.id_cliente, c.nome
 ORDER BY dias_sem_comprar DESC;

-- Novos em 2026: compraram em 2026 e nunca antes (contando só pedidos válidos).
-- Esperado: 8 Clinica Bem Estar Ltda (o pedido de 2025 foi cancelado)
SELECT c.id_cliente, c.nome
  FROM clientes c
 WHERE EXISTS (SELECT 1 FROM pedidos p
                WHERE p.id_cliente = c.id_cliente AND p.status <> 'CANCELADO'
                  AND p.data_pedido >= DATE '2026-01-01')
   AND NOT EXISTS (SELECT 1 FROM pedidos p
                    WHERE p.id_cliente = c.id_cliente AND p.status <> 'CANCELADO'
                      AND p.data_pedido < DATE '2026-01-01');

-- 4. A armadilha do NOT IN: funcionários que nunca venderam.
-- Esperado: nenhuma linha. Os pedidos do site têm id_vendedor NULL, e
--           "x NOT IN (..., NULL)" nunca é verdadeiro.
SELECT id_funcionario, nome
  FROM funcionarios
 WHERE id_funcionario NOT IN (SELECT id_vendedor FROM pedidos);

-- Com NOT EXISTS.
-- Esperado: 9 funcionários: 100, 101, 102, 103, 109, 110, 111, 112, 113
SELECT f.id_funcionario, f.nome
  FROM funcionarios f
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_vendedor = f.id_funcionario)
 ORDER BY f.id_funcionario;

-- NOT IN corrigido (filtrando os NULL da subconsulta).
-- Esperado: os mesmos 9
SELECT id_funcionario, nome
  FROM funcionarios
 WHERE id_funcionario NOT IN (SELECT id_vendedor FROM pedidos WHERE id_vendedor IS NOT NULL)
 ORDER BY id_funcionario;

-- 5. MINUS para listas de chaves.
-- Esperado: 15 (o produto inativo, nunca vendido)
SELECT id_produto FROM produtos
MINUS
SELECT id_produto FROM itens_pedido;

-- 6. O plano: NOT EXISTS vira anti-join.
EXPLAIN PLAN FOR
SELECT c.id_cliente FROM clientes c
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente);
-- Esperado: HASH JOIN ANTI ou NESTED LOOPS ANTI
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
