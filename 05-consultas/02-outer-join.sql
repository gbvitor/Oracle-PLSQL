-- =============================================================================
-- Tópico : LEFT, RIGHT e FULL OUTER JOIN
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. LEFT JOIN: todos os departamentos, com ou sem funcionários.
-- Esperado: Diretoria 1 | Comercial 6 | Financeiro 3 | Logistica 3 | Marketing 0
SELECT d.id_departamento,
       d.nome,
       COUNT(f.id_funcionario) AS funcionarios
  FROM departamentos d
  LEFT JOIN funcionarios f ON f.id_departamento = d.id_departamento
 GROUP BY d.id_departamento, d.nome
 ORDER BY d.id_departamento;

-- COUNT(*) conta a linha do Marketing como 1.
-- Esperado: Marketing 1 (errado)
SELECT d.nome, COUNT(*) AS contagem_errada
  FROM departamentos d
  LEFT JOIN funcionarios f ON f.id_departamento = d.id_departamento
 WHERE d.id_departamento = 50
 GROUP BY d.nome;

-- 2. RIGHT JOIN é o LEFT com as tabelas trocadas: mesmo resultado do exemplo 1.
SELECT d.id_departamento, d.nome, COUNT(f.id_funcionario) AS funcionarios
  FROM funcionarios f
 RIGHT JOIN departamentos d ON f.id_departamento = d.id_departamento
 GROUP BY d.id_departamento, d.nome
 ORDER BY d.id_departamento;

-- 3. FULL OUTER JOIN: sobras dos dois lados.
-- Esperado: 15 linhas; Marketing sem funcionário e Nelson Prado sem departamento
SELECT d.nome AS departamento,
       f.nome AS funcionario
  FROM departamentos d
  FULL JOIN funcionarios f ON f.id_departamento = d.id_departamento
 ORDER BY d.nome NULLS LAST, f.nome;

-- Só as sobras.
-- Esperado: Marketing | (nulo)  e  (nulo) | Nelson Prado
SELECT d.nome AS departamento, f.nome AS funcionario
  FROM departamentos d
  FULL JOIN funcionarios f ON f.id_departamento = d.id_departamento
 WHERE d.id_departamento IS NULL
    OR f.id_funcionario  IS NULL;

-- 4. Condição no ON versus no WHERE.
--    No ON: todos os clientes; os pedidos em aberto, quando houver.
-- Esperado: 12 linhas (9 clientes com pedido nulo + 3 com pedido aberto)
SELECT c.id_cliente, p.id_pedido
  FROM clientes c
  LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
                     AND p.status     = 'ABERTO'
 ORDER BY c.id_cliente;

--    No WHERE: o outer join vira inner.
-- Esperado: 3 linhas (clientes 1, 6, 9)
SELECT c.id_cliente, p.id_pedido
  FROM clientes c
  LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
 WHERE p.status = 'ABERTO'
 ORDER BY c.id_cliente;

-- 5. Anti-join: a condição IS NULL no WHERE sobre a chave da tabela opcional.
-- Esperado: 11 e 12
SELECT c.id_cliente, c.nome
  FROM clientes c
  LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
 WHERE p.id_pedido IS NULL;

-- 6. Encadeamento: um inner join depois do left desfaz o left.
-- Esperado: 10 clientes (11 e 12 somem)
SELECT COUNT(DISTINCT c.id_cliente) AS clientes
  FROM clientes c
  LEFT JOIN pedidos      p ON p.id_cliente = c.id_cliente
       JOIN itens_pedido i ON i.id_pedido  = p.id_pedido;

-- Certo: left em toda a cadeia.
-- Esperado: 12 clientes; 11 e 12 com valor nulo
SELECT c.id_cliente,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor_comprado
  FROM clientes c
  LEFT JOIN pedidos      p ON p.id_cliente = c.id_cliente
                          AND p.status    <> 'CANCELADO'
  LEFT JOIN itens_pedido i ON i.id_pedido  = p.id_pedido
 GROUP BY c.id_cliente
 ORDER BY c.id_cliente;

-- 7. Pedido com vendedor quando houver: LEFT JOIN preserva as vendas pelo site.
-- Esperado: 24 linhas; 1005, 1012 e 1024 com vendedor "site"
SELECT p.id_pedido,
       NVL(f.nome, 'site') AS vendedor
  FROM pedidos p
  LEFT JOIN funcionarios f ON f.id_funcionario = p.id_vendedor
 ORDER BY p.id_pedido;
