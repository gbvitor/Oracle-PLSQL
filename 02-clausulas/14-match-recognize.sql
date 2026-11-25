-- =============================================================================
-- Tópico : MATCH_RECOGNIZE — padrões em sequências de linhas
-- Seção  : 02-clausulas
-- Versão : 19c (disponível desde o 12c)
-- Requer : schema de exemplo (00-ambiente)
--
-- Base: valor de cada pedido válido, em ordem de data, por cliente.
--   cliente 1 : 1001 1045.50 | 1006 2046.00 | 1015 1311.50 | 1022 1513.00
--   cliente 2 : 1003 3945.03 | 1011 6019.15 | 1021 4076.64
--   cliente 3 : 1002 16276.50 | 1009 5163.44 | 1017 7554.28
--   cliente 6 : 1004 1761.80 | 1013 2609.31 | 1024 3150.00
--   cliente 10: 1008 27286.00 | 1014 15962.70 | 1020 16832.88
-- =============================================================================

-- 1. Sequências de alta: cada pedido maior que o anterior do mesmo cliente.
-- Esperado: 8 ocorrências
--   cliente 1: 1001-1006 e 1015-1022 | cliente 2: 1003-1011 | cliente 3: 1009-1017
--   cliente 4: 1005-1019 | cliente 6: 1004-1024 (3 pedidos) | cliente 9: 1012-1023
--   cliente 10: 1014-1020
WITH pedidos_valor AS (
    SELECT p.id_cliente, p.id_pedido, p.data_pedido,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_cliente, p.id_pedido, p.data_pedido
)
SELECT *
  FROM pedidos_valor
 MATCH_RECOGNIZE (
     PARTITION BY id_cliente
     ORDER BY data_pedido
     MEASURES
         FIRST(id_pedido)       AS pedido_inicial,
         LAST(id_pedido)        AS pedido_final,
         COUNT(*)               AS pedidos,
         FIRST(valor)           AS valor_inicial,
         LAST(valor)            AS valor_final
     ONE ROW PER MATCH
     AFTER MATCH SKIP PAST LAST ROW
     PATTERN (inicio alta+)
     DEFINE
         alta AS valor > PREV(valor)
 )
 ORDER BY id_cliente, pedido_inicial;

-- 2. Só as altas de pelo menos dois passos (três pedidos seguidos subindo).
-- Esperado: 1 ocorrência, cliente 6 (1004 -> 1013 -> 1024)
WITH pedidos_valor AS (
    SELECT p.id_cliente, p.id_pedido, p.data_pedido,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_cliente, p.id_pedido, p.data_pedido
)
SELECT *
  FROM pedidos_valor
 MATCH_RECOGNIZE (
     PARTITION BY id_cliente
     ORDER BY data_pedido
     MEASURES
         FIRST(id_pedido) AS pedido_inicial,
         LAST(id_pedido)  AS pedido_final,
         COUNT(*)         AS pedidos
     ONE ROW PER MATCH
     PATTERN (inicio alta{2,})
     DEFINE
         alta AS valor > PREV(valor)
 );

-- 3. Queda seguida de recuperação (formato V), com todas as linhas da
--    ocorrência e a classificação de cada uma.
-- Esperado: 3 ocorrências, 9 linhas
--   cliente 1 : 1006 (INICIO), 1015 (QUEDA), 1022 (ALTA)
--   cliente 3 : 1002 (INICIO), 1009 (QUEDA), 1017 (ALTA)
--   cliente 10: 1008 (INICIO), 1014 (QUEDA), 1020 (ALTA)
WITH pedidos_valor AS (
    SELECT p.id_cliente, p.id_pedido, p.data_pedido,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_cliente, p.id_pedido, p.data_pedido
)
SELECT id_cliente, ocorrencia, id_pedido, valor, etapa
  FROM pedidos_valor
 MATCH_RECOGNIZE (
     PARTITION BY id_cliente
     ORDER BY data_pedido
     MEASURES
         MATCH_NUMBER() AS ocorrencia,
         CLASSIFIER()   AS etapa
     ALL ROWS PER MATCH
     PATTERN (inicio queda+ alta+)
     DEFINE
         queda AS valor < PREV(valor),
         alta  AS valor > PREV(valor)
 )
 ORDER BY id_cliente, data_pedido;

-- 4. Intervalo entre pedidos: clientes com dois pedidos seguidos a menos de
--    120 dias um do outro.
-- Esperado: 1 ocorrência, cliente 1, de 1001 a 1006, 79 dias
WITH pedidos_validos AS (
    SELECT id_cliente, id_pedido, data_pedido
      FROM pedidos
     WHERE status <> 'CANCELADO'
)
SELECT *
  FROM pedidos_validos
 MATCH_RECOGNIZE (
     PARTITION BY id_cliente
     ORDER BY data_pedido
     MEASURES
         FIRST(id_pedido)                          AS de_pedido,
         LAST(id_pedido)                           AS ate_pedido,
         ROUND(LAST(data_pedido) - FIRST(data_pedido)) AS dias
     ONE ROW PER MATCH
     PATTERN (inicio perto+)
     DEFINE
         perto AS data_pedido - PREV(data_pedido) < 120
 )
 ORDER BY id_cliente, de_pedido;
