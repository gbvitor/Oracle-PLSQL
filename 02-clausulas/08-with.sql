-- =============================================================================
-- Tópico : WITH — CTE, encadeamento, recursão, WITH FUNCTION
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Bloco reutilizado: vendedores acima da média dos vendedores.
--    Média dos 5 vendedores: 23469.61
-- Esperado: 108 (60081.58) e 106 (30501.92)
WITH vendas_vendedor AS (
    SELECT p.id_vendedor,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS total
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
       AND p.id_vendedor IS NOT NULL
     GROUP BY p.id_vendedor
)
SELECT v.id_vendedor, f.nome, v.total
  FROM vendas_vendedor v
  JOIN funcionarios    f ON f.id_funcionario = v.id_vendedor
 WHERE v.total > (SELECT AVG(total) FROM vendas_vendedor)
 ORDER BY v.total DESC;

-- 2. Etapas encadeadas: item -> pedido -> cliente.
WITH itens_valor AS (
    SELECT id_pedido,
           ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2) AS valor
      FROM itens_pedido
),
pedidos_valor AS (
    SELECT p.id_pedido, p.id_cliente, SUM(iv.valor) AS valor_pedido
      FROM pedidos     p
      JOIN itens_valor iv ON iv.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_pedido, p.id_cliente
),
clientes_valor AS (
    SELECT id_cliente,
           COUNT(*)          AS pedidos,
           SUM(valor_pedido) AS total,
           AVG(valor_pedido) AS ticket_medio
      FROM pedidos_valor
     GROUP BY id_cliente
)
SELECT c.nome, cv.pedidos, cv.total, ROUND(cv.ticket_medio, 2) AS ticket_medio
  FROM clientes_valor cv
  JOIN clientes       c ON c.id_cliente = cv.id_cliente
 ORDER BY cv.total DESC;

-- 3. WITH recursivo: organograma com nível e caminho.
--    SEARCH DEPTH FIRST gera a coluna "ordem" para listar como árvore.
-- Esperado: 14 linhas; nível máximo 4
WITH org (id_funcionario, nome, cargo, nivel, caminho) AS (
    SELECT id_funcionario, nome, cargo, 1, CAST(nome AS VARCHAR2(4000))
      FROM funcionarios
     WHERE id_gerente IS NULL
    UNION ALL
    SELECT f.id_funcionario, f.nome, f.cargo, o.nivel + 1, o.caminho || ' > ' || f.nome
      FROM funcionarios f
      JOIN org          o ON f.id_gerente = o.id_funcionario
)
SEARCH DEPTH FIRST BY nome SET ordem
SELECT LPAD(' ', (nivel - 1) * 2) || nome AS organograma,
       cargo,
       nivel,
       caminho
  FROM org
 ORDER BY ordem;

-- 4. Caminho completo de cada categoria.
-- Esperado: Escritorio / Moveis / Cadeiras ... Informatica / Perifericos
WITH arvore (id_categoria, nome, caminho) AS (
    SELECT id_categoria, nome, CAST(nome AS VARCHAR2(4000))
      FROM categorias
     WHERE id_categoria_pai IS NULL
    UNION ALL
    SELECT c.id_categoria, c.nome, a.caminho || ' / ' || c.nome
      FROM categorias c
      JOIN arvore     a ON c.id_categoria_pai = a.id_categoria
)
SELECT id_categoria, caminho
  FROM arvore
 ORDER BY caminho;

-- 5. WITH recursivo como gerador: calendário de outubro/2026 com a
--    quantidade de pedidos de cada dia, inclusive dias sem pedido.
-- Esperado: 31 dias; 14/10 e 30/10 com 1 pedido, os demais com 0
WITH dias (dia) AS (
    SELECT DATE '2026-10-01' FROM dual
    UNION ALL
    SELECT dia + 1 FROM dias WHERE dia < DATE '2026-10-31'
)
SELECT d.dia,
       COUNT(p.id_pedido) AS pedidos
  FROM dias    d
  LEFT JOIN pedidos p
    ON p.data_pedido >= d.dia
   AND p.data_pedido <  d.dia + 1
 GROUP BY d.dia
 ORDER BY d.dia;

-- 6. CYCLE: detectar ciclo em dados hierárquicos.
--    Tabela temporária com um ciclo proposital: 1 -> 2 -> 3 -> 1.
CREATE TABLE tmp_rede (id NUMBER, id_pai NUMBER);
INSERT INTO tmp_rede VALUES (1, 3);
INSERT INTO tmp_rede VALUES (2, 1);
INSERT INTO tmp_rede VALUES (3, 2);
COMMIT;

-- Sem CYCLE.
-- Esperado: ORA-32044 (ciclo detectado ao executar consulta WITH recursiva)
WITH r (id, id_pai, nivel) AS (
    SELECT id, id_pai, 1 FROM tmp_rede WHERE id = 1
    UNION ALL
    SELECT t.id, t.id_pai, r.nivel + 1 FROM tmp_rede t JOIN r ON t.id_pai = r.id
)
SELECT * FROM r;

-- Com CYCLE: a recursão para ao reencontrar um id, e a linha é marcada.
-- Esperado: 4 linhas; a última (id 1 de novo) com ciclo = 'S'
WITH r (id, id_pai, nivel) AS (
    SELECT id, id_pai, 1 FROM tmp_rede WHERE id = 1
    UNION ALL
    SELECT t.id, t.id_pai, r.nivel + 1 FROM tmp_rede t JOIN r ON t.id_pai = r.id
)
CYCLE id SET ciclo TO 'S' DEFAULT 'N'
SELECT * FROM r;

DROP TABLE tmp_rede PURGE;

-- 7. WITH FUNCTION [12c+]: função PL/SQL declarada na consulta.
--    No SQL*Plus/SQLcl, o comando termina com "/" numa linha sozinha.
-- Esperado: 23 pedidos válidos; os maiores são 1008 (27286.00), 1020 e 1002
WITH
    FUNCTION valor_liquido(p_qtd NUMBER, p_preco NUMBER, p_desc NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN ROUND(p_qtd * p_preco * (1 - p_desc / 100), 2);
    END;
SELECT i.id_pedido,
       SUM(valor_liquido(i.quantidade, i.preco_unitario, i.pct_desconto)) AS valor
  FROM itens_pedido i
  JOIN pedidos      p ON p.id_pedido = i.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY i.id_pedido
 ORDER BY valor DESC
/
