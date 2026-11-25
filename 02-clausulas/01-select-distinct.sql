-- =============================================================================
-- Tópico : SELECT e DISTINCT
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Todas as colunas.
SELECT * FROM departamentos;

-- 2. Colunas, expressões e aliases.
SELECT nome,
       salario,
       salario * 12                AS salario_anual,
       salario * 12 * 1.0833       AS "Anual com 13o",
       UPPER(cargo)                AS cargo_maiusculo,
       'CLT'                       AS regime
  FROM funcionarios
 ORDER BY salario_anual DESC;

-- 3. Todas as colunas de uma tabela mais uma coluna de outra.
SELECT p.*, c.nome AS cliente
  FROM pedidos  p
  JOIN clientes c ON c.id_cliente = p.id_cliente
 WHERE p.id_pedido = 1001;

-- 4. Subquery escalar na lista de seleção: um valor por linha.
SELECT c.nome,
       (SELECT COUNT(*) FROM pedidos p WHERE p.id_cliente = c.id_cliente) AS qtd_pedidos
  FROM clientes c
 ORDER BY qtd_pedidos DESC, c.nome;

-- 5. DISTINCT sobre uma coluna.
-- Esperado: 11 cargos (14 funcionários)
SELECT DISTINCT cargo FROM funcionarios ORDER BY cargo;

-- 6. DISTINCT sobre várias colunas: a combinação é que precisa ser distinta.
-- Esperado: 11 combinações cidade + UF (12 clientes; dois em Sao Paulo/SP)
SELECT DISTINCT cidade, uf FROM clientes ORDER BY uf, cidade;

-- 7. NULL aparece uma vez só.
-- Esperado: 10, 20, 30, 40 e uma linha nula
SELECT DISTINCT id_departamento FROM funcionarios ORDER BY id_departamento;

-- 8. COUNT(DISTINCT) versus COUNT.
-- Esperado: 12 | 12 | 10
SELECT COUNT(*)           AS clientes,
       COUNT(uf)          AS com_uf,
       COUNT(DISTINCT uf) AS ufs_distintas
  FROM clientes;

-- 9. DISTINCT escondendo a granularidade do join.
--    "Clientes que têm pedido": o join gera uma linha por pedido.
-- Esperado: 24 linhas (uma por pedido)
SELECT c.id_cliente, c.nome
  FROM clientes c
  JOIN pedidos  p ON p.id_cliente = c.id_cliente;

-- Com DISTINCT o resultado fica certo, mas as 24 linhas são montadas antes.
-- Esperado: 10 linhas
SELECT DISTINCT c.id_cliente, c.nome
  FROM clientes c
  JOIN pedidos  p ON p.id_cliente = c.id_cliente
 ORDER BY c.id_cliente;

-- EXISTS responde a pergunta sem multiplicar linhas.
-- Esperado: 10 linhas
SELECT c.id_cliente, c.nome
  FROM clientes c
 WHERE EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente)
 ORDER BY c.id_cliente;

-- 10. UNIQUE é sinônimo de DISTINCT no Oracle.
SELECT UNIQUE uf FROM clientes ORDER BY uf;
