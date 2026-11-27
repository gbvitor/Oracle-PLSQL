-- =============================================================================
-- Tópico : LATERAL, CROSS APPLY e OUTER APPLY
-- Seção  : 05-consultas
-- Versão : 19c (disponível desde o 12c)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Inline view comum não enxerga a tabela anterior.
-- Esperado: ORA-00904 ("C"."ID_CLIENTE": identificador inválido)
SELECT c.nome, u.id_pedido
  FROM clientes c,
       (SELECT p.id_pedido FROM pedidos p WHERE p.id_cliente = c.id_cliente) u;

-- 2. CROSS APPLY: os 2 pedidos mais recentes de cada cliente.
--    Clientes com 1 pedido aparecem uma vez; sem pedido, não aparecem.
-- Esperado: 18 linhas (8 clientes com 2 ou mais pedidos x 2 + clientes 5 e 7 x 1)
SELECT c.id_cliente, c.nome, u.id_pedido, u.data_pedido
  FROM clientes c
 CROSS APPLY (SELECT p.id_pedido, p.data_pedido
                FROM pedidos p
               WHERE p.id_cliente = c.id_cliente
               ORDER BY p.data_pedido DESC
               FETCH FIRST 2 ROWS ONLY) u
 ORDER BY c.id_cliente, u.data_pedido DESC;

-- 3. LATERAL: mesma consulta, sintaxe do padrão SQL.
-- Esperado: 18
SELECT COUNT(*) AS linhas
  FROM clientes c,
       LATERAL (SELECT p.id_pedido
                  FROM pedidos p
                 WHERE p.id_cliente = c.id_cliente
                 ORDER BY p.data_pedido DESC
                 FETCH FIRST 2 ROWS ONLY) u;

-- 4. OUTER APPLY: mantém os clientes sem pedido.
-- Esperado: 20 linhas (18 + clientes 11 e 12 com pedido nulo)
SELECT c.id_cliente, c.nome, u.id_pedido, u.data_pedido
  FROM clientes c
 OUTER APPLY (SELECT p.id_pedido, p.data_pedido
                FROM pedidos p
               WHERE p.id_cliente = c.id_cliente
               ORDER BY p.data_pedido DESC
               FETCH FIRST 2 ROWS ONLY) u
 ORDER BY c.id_cliente, u.data_pedido DESC NULLS LAST;

-- 5. Resumo por linha com várias colunas (o que a subquery escalar não faz).
--    Para cada cliente: quantidade, primeiro e último pedido e valor total.
SELECT c.id_cliente, c.nome, r.pedidos, r.primeiro, r.ultimo, r.valor
  FROM clientes c
 OUTER APPLY (SELECT COUNT(DISTINCT p.id_pedido) AS pedidos,
                     MIN(p.data_pedido)          AS primeiro,
                     MAX(p.data_pedido)          AS ultimo,
                     SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
                FROM pedidos      p
                JOIN itens_pedido i ON i.id_pedido = p.id_pedido
               WHERE p.id_cliente = c.id_cliente
                 AND p.status    <> 'CANCELADO') r
 ORDER BY r.valor DESC NULLS LAST;
-- Agregação sem GROUP BY devolve sempre uma linha: os clientes 11 e 12
-- aparecem com 0 pedidos e valores nulos mesmo no CROSS APPLY.

-- 6. Expandir uma linha em várias: parcelas de pagamento.
--    Condições de pagamento de teste: número de parcelas e intervalo em dias.
-- Esperado: 1001 em 3x de 348.50 (30, 60, 90 dias) | 1008 em 2x de 13643.00 (30, 60)
WITH condicoes AS (
    SELECT 1001 AS id_pedido, 3 AS parcelas, 30 AS intervalo FROM dual UNION ALL
    SELECT 1008,              2,             30              FROM dual
),
valores AS (
    SELECT id_pedido,
           SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)) AS valor
      FROM itens_pedido
     GROUP BY id_pedido
)
SELECT c.id_pedido,
       x.parcela,
       TO_CHAR(TRUNC(p.data_pedido) + x.parcela * c.intervalo, 'DD/MM/YYYY') AS vencimento,
       ROUND(v.valor / c.parcelas, 2)                                         AS valor_parcela
  FROM condicoes c
  JOIN pedidos   p ON p.id_pedido = c.id_pedido
  JOIN valores   v ON v.id_pedido = c.id_pedido
 CROSS APPLY (SELECT LEVEL AS parcela FROM dual CONNECT BY LEVEL <= c.parcelas) x
 ORDER BY c.id_pedido, x.parcela;

-- 7. Calcular uma vez, usar várias vezes.
SELECT i.id_pedido, i.nr_item, calc.bruto, calc.desconto, calc.bruto - calc.desconto AS liquido
  FROM itens_pedido i
 CROSS APPLY (SELECT i.quantidade * i.preco_unitario                          AS bruto,
                     ROUND(i.quantidade * i.preco_unitario * i.pct_desconto / 100, 2) AS desconto
                FROM dual) calc
 WHERE i.id_pedido = 1002;
-- Esperado: item 1 bruto 8988 desconto 898.80 | item 2 3720 / 372 | item 3 5094 / 254.70
