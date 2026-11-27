-- =============================================================================
-- Tópico : UNION, UNION ALL, INTERSECT, MINUS
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. UNION remove repetidos; UNION ALL não.
--    Cidades de clientes (12 linhas, 11 distintas) e de departamentos
--    (5 linhas: Sao Paulo duas vezes, Belo Horizonte, Goiania e uma nula).
-- Esperado: 12 com UNION (11 cidades + o nulo) | 17 com UNION ALL
SELECT (SELECT COUNT(*) FROM (SELECT cidade FROM clientes
                              UNION
                              SELECT cidade FROM departamentos)) AS com_union,
       (SELECT COUNT(*) FROM (SELECT cidade FROM clientes
                              UNION ALL
                              SELECT cidade FROM departamentos)) AS com_union_all
  FROM dual;

-- 2. Lista combinada com a origem de cada linha e ORDER BY no fim.
SELECT 'cliente'      AS origem, nome, cidade FROM clientes
UNION ALL
SELECT 'funcionario',            nome, NULL   FROM funcionarios
 ORDER BY origem, nome;

-- 3. INTERSECT: clientes com pedido em 2025 e em 2026.
-- Esperado: 1, 2, 3, 4, 6, 8, 9, 10
SELECT id_cliente FROM pedidos WHERE data_pedido <  DATE '2026-01-01'
INTERSECT
SELECT id_cliente FROM pedidos WHERE data_pedido >= DATE '2026-01-01'
 ORDER BY 1;

-- 4. MINUS: clientes que compraram em 2025 e não voltaram em 2026.
-- Esperado: 5 e 7
SELECT id_cliente FROM pedidos WHERE data_pedido <  DATE '2026-01-01'
MINUS
SELECT id_cliente FROM pedidos WHERE data_pedido >= DATE '2026-01-01'
 ORDER BY 1;

-- O inverso: clientes novos em 2026.
-- Esperado: nenhuma linha
SELECT id_cliente FROM pedidos WHERE data_pedido >= DATE '2026-01-01'
MINUS
SELECT id_cliente FROM pedidos WHERE data_pedido <  DATE '2026-01-01';

-- 5. NULL é igual a NULL nos operadores de conjunto.
-- Esperado: 1 linha (as duas linhas (1, nulo) são consideradas iguais)
SELECT COUNT(*) AS linhas
  FROM (SELECT 1 AS a, CAST(NULL AS NUMBER) AS b FROM dual
        UNION
        SELECT 1, CAST(NULL AS NUMBER) FROM dual);

-- 6. Comparar duas tabelas: cópia de produtos com diferenças propositais.
CREATE TABLE tmp_produtos_copia AS SELECT * FROM produtos;

UPDATE tmp_produtos_copia SET preco_unitario = 41.90 WHERE id_produto = 1;
DELETE FROM tmp_produtos_copia WHERE id_produto = 15;
INSERT INTO tmp_produtos_copia VALUES (16, 'Produto so na copia', 2, 'UN', 10, 'S');
COMMIT;

-- Esperado: 4 linhas, ordenadas por produto
--   so_na_copia   1  (preço 41.90)
--   so_na_origem  1  (preço 39.90)
--   so_na_origem  15
--   so_na_copia   16
SELECT 'so_na_origem' AS lado, d.*
  FROM (SELECT id_produto, nome, preco_unitario, ativo FROM produtos
        MINUS
        SELECT id_produto, nome, preco_unitario, ativo FROM tmp_produtos_copia) d
UNION ALL
SELECT 'so_na_copia', d.*
  FROM (SELECT id_produto, nome, preco_unitario, ativo FROM tmp_produtos_copia
        MINUS
        SELECT id_produto, nome, preco_unitario, ativo FROM produtos) d
 ORDER BY 2, 1;

DROP TABLE tmp_produtos_copia PURGE;

-- 7. Colunas na ordem errada: tipos iguais, nenhum erro, dados misturados.
-- Esperado: a segunda parte mostra cidade na coluna "nome"
SELECT nome, cidade FROM clientes      WHERE id_cliente = 1
UNION ALL
SELECT cidade, nome FROM departamentos WHERE id_departamento = 10;

-- 8. Quantidade de colunas diferente: erro.
-- Esperado: ORA-01789 (o bloco de consulta tem um número incorreto de colunas de resultado)
SELECT nome, cidade FROM clientes
UNION
SELECT nome FROM departamentos;
