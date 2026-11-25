-- =============================================================================
-- Tópico : Comparação, ANY/SOME e ALL
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Salários dos vendedores: 4300, 4500, 4800, 5200.
-- =============================================================================

-- 1. Os três operadores de diferença são equivalentes.
-- Esperado: 23 | 23 | 23
SELECT (SELECT COUNT(*) FROM pedidos WHERE status <> 'CANCELADO') AS com_menor_maior,
       (SELECT COUNT(*) FROM pedidos WHERE status != 'CANCELADO') AS com_exclamacao,
       (SELECT COUNT(*) FROM pedidos WHERE status ^= 'CANCELADO') AS com_circunflexo
  FROM dual;

-- 2. Comparação de texto é binária: minúsculas vêm depois das maiúsculas.
-- Esperado: verdadeiro | falso
SELECT CASE WHEN 'a' > 'Z' THEN 'verdadeiro' ELSE 'falso' END AS a_maior_que_z,
       CASE WHEN 'a' > 'b' THEN 'verdadeiro' ELSE 'falso' END AS a_maior_que_b
  FROM dual;

-- 3. > ALL: maior que todos os vendedores (maior que 5200).
-- Esperado: 7 (100, 101, 102, 103, 108, 109, 111)
SELECT COUNT(*) AS acima_de_todos
  FROM funcionarios
 WHERE salario > ALL (SELECT salario FROM funcionarios WHERE cargo = 'Vendedor');

-- 4. > ANY: maior que pelo menos um vendedor (maior que 4300).
-- Esperado: 10
SELECT COUNT(*) AS acima_de_algum
  FROM funcionarios
 WHERE salario > ANY (SELECT salario FROM funcionarios WHERE cargo = 'Vendedor');

-- 5. Lista literal.
-- Esperado: 1001, 1002, 1003
SELECT id_pedido FROM pedidos WHERE id_pedido < ALL (1004, 1005, 1010) ORDER BY id_pedido;

-- 6. Lista vazia: ALL é verdadeiro, ANY é falso, MAX dá nulo.
--    Não existe cargo 'Gerente de Vendas', então a subquery não devolve nada.
-- Esperado: 14 | 0 | 0
SELECT (SELECT COUNT(*) FROM funcionarios
         WHERE salario > ALL (SELECT salario FROM funcionarios WHERE cargo = 'Gerente de Vendas')) AS com_all,
       (SELECT COUNT(*) FROM funcionarios
         WHERE salario > ANY (SELECT salario FROM funcionarios WHERE cargo = 'Gerente de Vendas')) AS com_any,
       (SELECT COUNT(*) FROM funcionarios
         WHERE salario > (SELECT MAX(salario) FROM funcionarios WHERE cargo = 'Gerente de Vendas')) AS com_max
  FROM dual;

-- 7. NULL na lista: > ALL nunca é verdadeiro.
--    pct_comissao de todos os funcionários inclui nulos.
-- Esperado: 0
SELECT COUNT(*) AS acima_de_todas_comissoes
  FROM funcionarios
 WHERE 100 > ALL (SELECT pct_comissao FROM funcionarios);

-- 8. = ANY é o mesmo que IN.
-- Esperado: 3 | 3
SELECT (SELECT COUNT(*) FROM clientes WHERE uf = ANY ('SP', 'RJ')) AS com_any,
       (SELECT COUNT(*) FROM clientes WHERE uf IN ('SP', 'RJ'))     AS com_in
  FROM dual;
