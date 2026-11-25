-- =============================================================================
-- Tópico : BETWEEN
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Os dois limites entram.
-- Esperado: 4 (107 = 4300, 105 = 4500, 104 = 4800, 106 = 5200)
SELECT nome, salario
  FROM funcionarios
 WHERE salario BETWEEN 4300 AND 5200
 ORDER BY salario;

-- 2. Limites invertidos: nenhuma linha, sem erro.
-- Esperado: 0
SELECT COUNT(*) AS limites_invertidos
  FROM funcionarios
 WHERE salario BETWEEN 5200 AND 4300;

-- 3. NOT BETWEEN.
-- Esperado: 10
SELECT COUNT(*) AS fora_da_faixa
  FROM funcionarios
 WHERE salario NOT BETWEEN 4300 AND 5200;

-- 4. Datas: BETWEEN perde o último dia.
--    O pedido 1024 é de 30/10/2026 às 20:30.
-- Esperado: 1 | 2 | 2
SELECT (SELECT COUNT(*) FROM pedidos
         WHERE data_pedido BETWEEN DATE '2026-10-01' AND DATE '2026-10-30')          AS between_data,
       (SELECT COUNT(*) FROM pedidos
         WHERE data_pedido >= DATE '2026-10-01' AND data_pedido < DATE '2026-10-31') AS semiaberto,
       (SELECT COUNT(*) FROM pedidos
         WHERE TRUNC(data_pedido) BETWEEN DATE '2026-10-01' AND DATE '2026-10-30')   AS com_trunc
  FROM dual;

-- 5. Texto: "Carla" fica fora de BETWEEN 'A' AND 'C'.
-- Esperado: Ana Ribeiro, Bruno Carvalho
SELECT nome FROM funcionarios WHERE nome BETWEEN 'A' AND 'C' ORDER BY nome;

-- Para "começa com A, B ou C".
-- Esperado: Ana Ribeiro, Bruno Carvalho, Carla Mendes
SELECT nome FROM funcionarios WHERE nome >= 'A' AND nome < 'D' ORDER BY nome;

-- 6. NULL no limite: nenhuma linha.
-- Esperado: 0
SELECT COUNT(*) AS limite_nulo
  FROM funcionarios
 WHERE salario BETWEEN 4000 AND NULL;
