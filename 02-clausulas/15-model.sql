-- =============================================================================
-- Tópico : MODEL — cálculo em estilo planilha
-- Seção  : 02-clausulas
-- Versão : 19c (disponível desde o 10g)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Projeção de vendas por vendedor: 2027 e 2028 com crescimento de 10% a.a.
--    sobre 2026. As células de 2027 e 2028 não existem nos dados: são criadas
--    pelas regras (UPSERT).
-- Esperado (2027 | 2028):
--   104   6148.60 |  6763.46
--   105    186.67 |   205.34
--   106   9968.18 | 10965.00
--   107    988.90 |  1087.79
--   108  18516.17 | 20367.79
--   site  3465.00 |  3811.50
SELECT vendedor, ano, valor
  FROM (SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
               EXTRACT(YEAR FROM p.data_pedido)     AS ano,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO'
         GROUP BY p.id_vendedor, EXTRACT(YEAR FROM p.data_pedido))
 MODEL
     PARTITION BY (vendedor)
     DIMENSION BY (ano)
     MEASURES (valor)
     RULES (
         valor[2027] = ROUND(valor[2026] * 1.10, 2),
         valor[2028] = ROUND(valor[2027] * 1.10, 2)
     )
 ORDER BY vendedor, ano;

-- 2. A mesma projeção com uma regra relativa (CV) e só as linhas novas.
--    FOR ano FROM 2027 TO 2028 INCREMENT 1 cria as células em sequência;
--    CV(ano) - 1 aponta para o ano anterior de cada célula.
-- Esperado: 12 linhas (6 vendedores x 2 anos), mesmos valores do exemplo 1
SELECT vendedor, ano, valor
  FROM (SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
               EXTRACT(YEAR FROM p.data_pedido)     AS ano,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO'
         GROUP BY p.id_vendedor, EXTRACT(YEAR FROM p.data_pedido))
 MODEL
     RETURN UPDATED ROWS
     PARTITION BY (vendedor)
     DIMENSION BY (ano)
     MEASURES (valor)
     RULES (
         valor[FOR ano FROM 2027 TO 2028 INCREMENT 1] = ROUND(valor[CV(ano) - 1] * 1.10, 2)
     )
 ORDER BY vendedor, ano;

-- 3. Medida calculada a partir de outras células: variação 2026 x 2025.
--    A medida "variacao_pct" começa nula e é preenchida só na célula de 2026.
SELECT vendedor, ano, valor, variacao_pct
  FROM (SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
               EXTRACT(YEAR FROM p.data_pedido)     AS ano,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO'
         GROUP BY p.id_vendedor, EXTRACT(YEAR FROM p.data_pedido))
 MODEL
     PARTITION BY (vendedor)
     DIMENSION BY (ano)
     MEASURES (valor, CAST(NULL AS NUMBER) AS variacao_pct)
     RULES (
         variacao_pct[2026] = ROUND((valor[2026] / valor[2025] - 1) * 100, 1)
     )
 ORDER BY vendedor, ano;

-- 4. Equivalente do exemplo 3 com função analítica: em geral, mais legível.
SELECT vendedor, ano, valor,
       ROUND((valor / LAG(valor) OVER (PARTITION BY vendedor ORDER BY ano) - 1) * 100, 1) AS variacao_pct
  FROM (SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
               EXTRACT(YEAR FROM p.data_pedido)     AS ano,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO'
         GROUP BY p.id_vendedor, EXTRACT(YEAR FROM p.data_pedido))
 ORDER BY vendedor, ano;
