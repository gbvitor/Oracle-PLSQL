-- =============================================================================
-- Tópico : Funções de agregação e LISTAGG
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Resumo de vendas por categoria (sem cancelados).
-- Esperado (categoria: itens | pedidos | total | média | menor | maior):
--   2: 18 | 12 | 24454.42 | 1358.58 |  39.90 |  8267.70
--   3: 10 |  9 | 15673.78 | 1567.38 |  99.80 |  4275.00
--   5: 14 |  7 | 11822.11 |  844.44 | 210.00 |  2340.00
--   6:  5 |  3 | 23959.08 | 4791.82 | 3348.00 |  6479.28
--   7:  6 |  6 | 45108.04 | 7518.01 | 1116.00 | 16720.00
SELECT pr.id_categoria,
       COUNT(*)                    AS itens,
       COUNT(DISTINCT i.id_pedido) AS pedidos,
       SUM(v.valor)                AS total,
       ROUND(AVG(v.valor), 2)      AS media,
       MIN(v.valor)                AS menor,
       MAX(v.valor)                AS maior
  FROM itens_pedido i
  JOIN pedidos      p  ON p.id_pedido   = i.id_pedido
  JOIN produtos     pr ON pr.id_produto = i.id_produto
 -- CROSS APPLY (seção 05) calcula o valor do item uma vez e dá nome a ele.
 CROSS APPLY (SELECT ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2) AS valor
                FROM dual) v
 WHERE p.status <> 'CANCELADO'
 GROUP BY pr.id_categoria
 ORDER BY pr.id_categoria;

-- 2. MIN e MAX em data e texto.
-- Esperado: 2025-01-08 09:15 | 2026-10-30 20:30 | Clinica Bem Estar Ltda | Thiago Nunes
SELECT TO_CHAR(MIN(p.data_pedido), 'YYYY-MM-DD HH24:MI') AS primeiro_pedido,
       TO_CHAR(MAX(p.data_pedido), 'YYYY-MM-DD HH24:MI') AS ultimo_pedido,
       (SELECT MIN(nome) FROM clientes)                   AS primeiro_nome,
       (SELECT MAX(nome) FROM clientes)                   AS ultimo_nome
  FROM pedidos p;

-- 3. Estatística: média, mediana, desvio padrão, percentis.
-- Esperado: média 7928.57 | mediana 5300 | desvio 6257.6 | p25 4350 | p75 10950 | p75 discreto 12000
SELECT ROUND(AVG(salario), 2)                                         AS media,
       MEDIAN(salario)                                                AS mediana,
       ROUND(STDDEV(salario), 2)                                      AS desvio_padrao,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salario)          AS p25,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salario)          AS p75,
       PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY salario)          AS p75_discreto
  FROM funcionarios;

-- 4. Agregação sobre conjunto vazio.
--    Sem GROUP BY: uma linha (0 e nulo). Com GROUP BY: nenhuma linha.
-- Esperado: 0 | nulo
SELECT COUNT(*) AS qtd, SUM(salario) AS soma
  FROM funcionarios
 WHERE id_departamento = 50;

-- Esperado: nenhuma linha
SELECT id_departamento, COUNT(*) AS qtd
  FROM funcionarios
 WHERE id_departamento = 50
 GROUP BY id_departamento;

-- 5. LISTAGG: funcionários de cada departamento numa linha.
-- Esperado: 20 -> Bruno Carvalho, Eduarda Lima, Felipe Souza, Gabriela Rocha,
--                 Henrique Alves, Isabela Costa
SELECT id_departamento,
       COUNT(*)                                                 AS qtd,
       LISTAGG(nome, ', ') WITHIN GROUP (ORDER BY nome)          AS funcionarios
  FROM funcionarios
 GROUP BY id_departamento
 ORDER BY id_departamento;

-- 6. LISTAGG DISTINCT [19c+]: cargos distintos por departamento.
-- Esperado: 20 -> Gerente Comercial, Supervisor de Vendas, Vendedor
SELECT id_departamento,
       LISTAGG(DISTINCT cargo, ', ') WITHIN GROUP (ORDER BY cargo) AS cargos
  FROM funcionarios
 GROUP BY id_departamento
 ORDER BY id_departamento;

-- 7. Produtos de cada pedido na ordem dos itens.
-- Esperado: 1001 -> 8, 9, 10 | 1008 -> 13, 11, 12, 7
SELECT id_pedido,
       LISTAGG(id_produto, ', ') WITHIN GROUP (ORDER BY nr_item) AS produtos
  FROM itens_pedido
 WHERE id_pedido IN (1001, 1008)
 GROUP BY id_pedido;

-- 8. Estouro do LISTAGG e ON OVERFLOW TRUNCATE.
--    5000 linhas de "abc" passam de 4000 bytes.
-- Esperado: ORA-01489 (o resultado da concatenação de string é muito longo)
SELECT LISTAGG('abc', ',') WITHIN GROUP (ORDER BY NULL) AS lista
  FROM dual CONNECT BY LEVEL <= 5000;

-- Com truncamento: termina em ",...(nnnn)" com a quantidade omitida.
SELECT LENGTH(lista) AS tamanho, SUBSTR(lista, -20) AS final
  FROM (SELECT LISTAGG('abc', ',' ON OVERFLOW TRUNCATE '...' WITH COUNT)
                   WITHIN GROUP (ORDER BY NULL) AS lista
          FROM dual CONNECT BY LEVEL <= 5000);

-- 9. KEEP: vendedor do último pedido de cada cliente, sem subquery.
--    O cliente 6 sai nulo: o último pedido dele (1024) foi pelo site.
-- Esperado: 1 104 | 2 104 | 3 106 | 4 105 | 5 105 | 6 nulo | 7 107 | 8 106 | 9 107 | 10 108
SELECT id_cliente,
       MAX(id_vendedor) KEEP (DENSE_RANK LAST ORDER BY data_pedido) AS vendedor_ultimo_pedido,
       MIN(id_pedido)   KEEP (DENSE_RANK FIRST ORDER BY data_pedido) AS primeiro_pedido
  FROM pedidos
 WHERE status <> 'CANCELADO'
 GROUP BY id_cliente
 ORDER BY id_cliente;
