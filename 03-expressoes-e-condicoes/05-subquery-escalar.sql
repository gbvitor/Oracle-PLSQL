-- =============================================================================
-- Tópico : Subquery escalar
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Correlacionada na lista do SELECT: último pedido de cada cliente.
-- Esperado: 12 linhas; clientes 11 e 12 com data nula (sem pedido, sem erro)
SELECT c.id_cliente,
       c.nome,
       (SELECT MAX(p.data_pedido)
          FROM pedidos p
         WHERE p.id_cliente = c.id_cliente) AS ultimo_pedido
  FROM clientes c
 ORDER BY c.id_cliente;

-- 2. Mais de uma linha: erro.
-- Esperado: ORA-01427 (subconsulta de uma única linha retorna mais de uma linha)
SELECT c.nome,
       (SELECT p.id_pedido FROM pedidos p WHERE p.id_cliente = c.id_cliente) AS pedido
  FROM clientes c;

-- Garantindo uma linha: o pedido mais recente.
SELECT c.nome,
       (SELECT p.id_pedido
          FROM pedidos p
         WHERE p.id_cliente = c.id_cliente
         ORDER BY p.data_pedido DESC
         FETCH FIRST 1 ROW ONLY) AS pedido_mais_recente
  FROM clientes c
 ORDER BY c.id_cliente;

-- 3. No WHERE: funcionários que ganham acima da média geral.
--    Média geral: 7928.57
-- Esperado: 100, 101, 102, 103 (quatro)
SELECT nome, salario
  FROM funcionarios
 WHERE salario > (SELECT AVG(salario) FROM funcionarios)
 ORDER BY salario DESC;

-- 4. Correlacionada no WHERE: acima da média do próprio departamento.
-- Esperado: 101 Bruno (Comercial), 108 Isabela (Comercial), 102 Carla (Financeiro),
--           103 Diego (Logistica)
SELECT f.nome, f.id_departamento, f.salario
  FROM funcionarios f
 WHERE f.salario > (SELECT AVG(f2.salario)
                      FROM funcionarios f2
                     WHERE f2.id_departamento = f.id_departamento)
 ORDER BY f.id_departamento, f.salario DESC;

-- 5. Dentro de CASE e de expressão.
SELECT c.nome,
       CASE
           WHEN (SELECT COUNT(*) FROM pedidos p WHERE p.id_cliente = c.id_cliente) = 0
               THEN 'sem pedido'
           WHEN (SELECT COUNT(*) FROM pedidos p WHERE p.id_cliente = c.id_cliente) >= 3
               THEN 'frequente'
           ELSE 'ocasional'
       END AS perfil
  FROM clientes c
 ORDER BY perfil, c.nome;

-- 6. Várias subqueries sobre a mesma tabela versus um join agregado.
--    As duas consultas dão o mesmo resultado; a segunda lê PEDIDOS uma vez.
SELECT c.nome,
       (SELECT COUNT(*)         FROM pedidos p WHERE p.id_cliente = c.id_cliente) AS qtd,
       (SELECT MIN(data_pedido) FROM pedidos p WHERE p.id_cliente = c.id_cliente) AS primeiro,
       (SELECT MAX(data_pedido) FROM pedidos p WHERE p.id_cliente = c.id_cliente) AS ultimo
  FROM clientes c
 ORDER BY c.id_cliente;

SELECT c.nome,
       NVL(r.qtd, 0) AS qtd,
       r.primeiro,
       r.ultimo
  FROM clientes c
  LEFT JOIN (SELECT id_cliente,
                    COUNT(*)         AS qtd,
                    MIN(data_pedido) AS primeiro,
                    MAX(data_pedido) AS ultimo
               FROM pedidos
              GROUP BY id_cliente) r
    ON r.id_cliente = c.id_cliente
 ORDER BY c.id_cliente;

-- 7. UPDATE com subquery escalar sem WHERE EXISTS: as linhas sem
--    correspondência recebem NULL.
--    Tabela de apoio com novos preços só para 2 produtos.
CREATE TABLE tmp_novos_precos (id_produto NUMBER, preco NUMBER(10,2));
INSERT INTO tmp_novos_precos VALUES (1, 42.00);
INSERT INTO tmp_novos_precos VALUES (2, 94.90);

-- Errado: os outros 13 produtos ficam com preço nulo (aqui o NOT NULL da
-- coluna impede e o comando falha).
-- Esperado: ORA-01407 (não é possível atualizar para NULL)
UPDATE produtos p
   SET preco_unitario = (SELECT n.preco FROM tmp_novos_precos n WHERE n.id_produto = p.id_produto);

-- Certo: atualizar só quem tem correspondência.
-- Esperado: 2 linhas atualizadas
UPDATE produtos p
   SET preco_unitario = (SELECT n.preco FROM tmp_novos_precos n WHERE n.id_produto = p.id_produto)
 WHERE EXISTS (SELECT 1 FROM tmp_novos_precos n WHERE n.id_produto = p.id_produto);

ROLLBACK;
DROP TABLE tmp_novos_precos PURGE;
