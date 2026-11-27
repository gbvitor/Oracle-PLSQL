-- =============================================================================
-- Tópico : CROSS JOIN, self join, NATURAL JOIN e USING
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. CROSS JOIN para montar uma grade: vendedores x trimestres de 2026,
--    com LEFT JOIN nos pedidos para mostrar também os trimestres sem venda.
-- Esperado: 20 linhas (5 vendedores x 4 trimestres); várias com 0 pedidos
WITH vendedores AS (
    SELECT id_funcionario, nome FROM funcionarios WHERE pct_comissao IS NOT NULL
),
trimestres AS (
    SELECT LEVEL AS trimestre FROM dual CONNECT BY LEVEL <= 4
)
SELECT v.nome,
       t.trimestre,
       COUNT(p.id_pedido) AS pedidos
  FROM vendedores v
 CROSS JOIN trimestres t
  LEFT JOIN pedidos p
    ON p.id_vendedor = v.id_funcionario
   AND p.data_pedido >= DATE '2026-01-01'
   AND p.data_pedido <  DATE '2027-01-01'
   AND TO_NUMBER(TO_CHAR(p.data_pedido, 'Q')) = t.trimestre
 GROUP BY v.nome, t.trimestre
 ORDER BY v.nome, t.trimestre;

-- 2. Self join: funcionário e gerente.
--    LEFT JOIN para não perder a diretora (sem gerente).
-- Esperado: 14 linhas; Ana Ribeiro com gerente nulo
SELECT f.nome AS funcionario,
       f.cargo,
       g.nome AS gerente
  FROM funcionarios f
  LEFT JOIN funcionarios g ON g.id_funcionario = f.id_gerente
 ORDER BY g.nome NULLS FIRST, f.nome;

-- Funcionários que ganham mais que o próprio gerente.
-- Esperado: nenhuma linha
SELECT f.nome, f.salario, g.nome AS gerente, g.salario AS salario_gerente
  FROM funcionarios f
  JOIN funcionarios g ON g.id_funcionario = f.id_gerente
 WHERE f.salario > g.salario;

-- 3. Self join para comparar pares: clientes da mesma cidade.
--    a.id < b.id evita (A,A) e a repetição (B,A).
-- Esperado: 1 par: Papelaria Central Ltda e Fernanda Araujo, Sao Paulo
SELECT a.nome AS cliente_a, b.nome AS cliente_b, a.cidade
  FROM clientes a
  JOIN clientes b ON b.cidade = a.cidade
                 AND b.uf     = a.uf
                 AND a.id_cliente < b.id_cliente;

-- 4. NATURAL JOIN: liga por todas as colunas de mesmo nome.
--    produtos e itens_pedido têm id_produto E preco_unitario em comum.
-- Esperado: 27 (só itens vendidos pelo preço de tabela), e não 54
SELECT COUNT(*) AS linhas_natural
  FROM produtos NATURAL JOIN itens_pedido;

-- O join que se queria.
-- Esperado: 54
SELECT COUNT(*) AS linhas_corretas
  FROM produtos     p
  JOIN itens_pedido i ON i.id_produto = p.id_produto;

-- 5. USING: explícito e seguro.
-- Esperado: 54
SELECT COUNT(*) AS linhas_using
  FROM produtos p
  JOIN itens_pedido i USING (id_produto);

-- A coluna do USING não pode ser qualificada.
-- Esperado: ORA-25154 (a parte da coluna da cláusula USING não pode ter qualificador)
SELECT p.id_produto
  FROM produtos p
  JOIN itens_pedido i USING (id_produto);

-- Sem qualificador, funciona.
SELECT id_produto, p.nome, i.id_pedido
  FROM produtos p
  JOIN itens_pedido i USING (id_produto)
 WHERE id_produto = 15;
-- Esperado: nenhuma linha (produto 15 nunca vendido)
