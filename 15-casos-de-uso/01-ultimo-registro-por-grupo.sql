-- =============================================================================
-- Caso   : Último pedido de cada cliente, inclusive de quem nunca comprou
-- Seção  : 15-casos-de-uso
-- Versão : 19c (LATERAL exige 12c+)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

COLUMN nome FORMAT A28

-- 1. ROW_NUMBER com desempate e LEFT JOIN.
-- Esperado:
--    1 Papelaria Central Ltda      1022 29/09/2026 ABERTO
--    2 Tech Solucoes ME            1021 05/08/2026 FATURADO
--    3 Escritorio Modelo SA        1017 20/01/2026 ENTREGUE
--    4 Marcos Antonio Silva        1019 07/04/2026 FATURADO
--    5 Patricia Moura              1010 17/06/2025 ENTREGUE
--    6 Colegio Saber Ltda          1024 30/10/2026 ABERTO
--    7 Rafael Teixeira             1016 12/12/2025 ENTREGUE
--    8 Clinica Bem Estar Ltda      1018 24/02/2026 ENTREGUE
--    9 Fernanda Araujo             1023 14/10/2026 ABERTO
--   10 Construtora Horizonte Ltda  1020 18/06/2026 FATURADO
--   11 Loja Antiga ME              (sem pedido)
--   12 Thiago Nunes                (sem pedido)
SELECT c.id_cliente,
       c.nome,
       u.id_pedido,
       TO_CHAR(u.data_pedido, 'DD/MM/YYYY') AS data_pedido,
       u.status
  FROM clientes c
  LEFT JOIN (SELECT p.*,
                    ROW_NUMBER() OVER (PARTITION BY p.id_cliente
                                       ORDER BY p.data_pedido DESC, p.id_pedido DESC) AS rn
               FROM pedidos p) u
    ON u.id_cliente = c.id_cliente
   AND u.rn = 1
 ORDER BY c.id_cliente;

-- 2. O erro comum: rn = 1 no WHERE elimina quem não tem pedido.
-- Esperado: 10 linhas (os clientes 11 e 12 sumiram)
SELECT COUNT(*)
  FROM clientes c
  LEFT JOIN (SELECT p.*,
                    ROW_NUMBER() OVER (PARTITION BY p.id_cliente ORDER BY p.data_pedido DESC) AS rn
               FROM pedidos p) u
    ON u.id_cliente = c.id_cliente
 WHERE u.rn = 1;

-- 3. Último pedido válido (sem os cancelados): o filtro vai dentro da subconsulta.
-- Nos dados de exemplo, nenhum cliente tem um cancelado como último pedido, então o
-- resultado não muda; o filtro importa quando tiver. O lugar dele é este: dentro da
-- subconsulta, antes do ROW_NUMBER (no WHERE externo, o cliente ficaria sem pedido).
SELECT c.id_cliente, u.id_pedido, u.status
  FROM clientes c
  LEFT JOIN (SELECT p.*,
                    ROW_NUMBER() OVER (PARTITION BY p.id_cliente
                                       ORDER BY p.data_pedido DESC, p.id_pedido DESC) AS rn
               FROM pedidos p
              WHERE p.status <> 'CANCELADO') u
    ON u.id_cliente = c.id_cliente
   AND u.rn = 1
 WHERE c.id_cliente IN (8, 11)
 ORDER BY c.id_cliente;
-- Esperado: 8 1018 ENTREGUE | 11 (vazio)

-- 4. KEEP DENSE_RANK LAST: o último valor junto com outras agregações, sem subconsulta.
-- Esperado (clientes 1, 3 e 8):
--   1 | 4 pedidos | primeiro 08/01/2025 | último 1022 ABERTO
--   3 | 3 pedidos | primeiro 15/01/2025 | último 1017 ENTREGUE
--   8 | 2 pedidos | primeiro 14/04/2025 | último 1018 ENTREGUE
SELECT id_cliente,
       COUNT(*) AS pedidos,
       TO_CHAR(MIN(data_pedido), 'DD/MM/YYYY') AS primeiro,
       MAX(id_pedido) KEEP (DENSE_RANK LAST ORDER BY data_pedido) AS ultimo_pedido,
       MAX(status)    KEEP (DENSE_RANK LAST ORDER BY data_pedido) AS ultimo_status
  FROM pedidos
 WHERE id_cliente IN (1, 3, 8)
 GROUP BY id_cliente
 ORDER BY id_cliente;

-- 5. LATERAL [12c+]: uma busca por cliente, boa para poucos clientes com índice.
-- Esperado: o mesmo do passo 1 para os clientes 1 e 2
SELECT c.id_cliente, c.nome, u.id_pedido, u.status
  FROM clientes c
  OUTER APPLY (SELECT p.id_pedido, p.status
                 FROM pedidos p
                WHERE p.id_cliente = c.id_cliente
                ORDER BY p.data_pedido DESC, p.id_pedido DESC
                FETCH FIRST 1 ROW ONLY) u
 WHERE c.id_cliente IN (1, 2)
 ORDER BY c.id_cliente;

-- 6. NOT EXISTS (portável): não existe pedido mais novo do mesmo cliente.
-- Esperado: 10 linhas, as mesmas do passo 1 sem os clientes 11 e 12
SELECT p.id_cliente, p.id_pedido, p.status
  FROM pedidos p
 WHERE NOT EXISTS (SELECT 1
                     FROM pedidos p2
                    WHERE p2.id_cliente = p.id_cliente
                      AND (p2.data_pedido > p.data_pedido
                           OR (p2.data_pedido = p.data_pedido AND p2.id_pedido > p.id_pedido)))
 ORDER BY p.id_cliente;
