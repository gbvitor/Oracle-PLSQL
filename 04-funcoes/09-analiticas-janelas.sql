-- =============================================================================
-- Tópico : Funções analíticas III — janelas, acumulados, médias móveis
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Acumulado e média móvel de 3 meses (só meses com venda).
-- Esperado (amostra):
--   2025-01 17322.00 | acum 17322.00  | mm3 17322.00
--   2025-03  2185.70 | acum 25214.53  | mm3  8404.84
--   2025-12   988.90 | acum 85314.23  (total de 2025)
--   2026-10  4049.00 | acum 121017.43 (total geral)
WITH mensal AS (
    SELECT TO_CHAR(p.data_pedido, 'YYYY-MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TO_CHAR(p.data_pedido, 'YYYY-MM')
)
SELECT mes,
       valor,
       SUM(valor) OVER (ORDER BY mes ROWS UNBOUNDED PRECEDING)                        AS acumulado,
       ROUND(AVG(valor) OVER (ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS media_movel_3,
       COUNT(*)   OVER (ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)          AS meses_na_media
  FROM mensal
 ORDER BY mes;

-- 2. Acumulado que recomeça a cada ano.
-- Esperado: 2025-12 acumulado 85314.23 | 2026-01 recomeça em 7554.28
WITH mensal AS (
    SELECT TO_CHAR(p.data_pedido, 'YYYY-MM') AS mes,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY TO_CHAR(p.data_pedido, 'YYYY-MM')
)
SELECT mes,
       valor,
       SUM(valor) OVER (PARTITION BY SUBSTR(mes, 1, 4) ORDER BY mes ROWS UNBOUNDED PRECEDING) AS acumulado_ano
  FROM mensal
 ORDER BY mes;

-- 3. Janela padrão: com e sem ORDER BY no OVER.
--    Sem ORDER BY: total do departamento em cada linha.
--    Com ORDER BY: acumulado dentro do departamento.
SELECT id_departamento, nome, salario,
       SUM(salario) OVER (PARTITION BY id_departamento)                  AS total_depto,
       SUM(salario) OVER (PARTITION BY id_departamento ORDER BY salario) AS acumulado_depto
  FROM funcionarios
 WHERE id_departamento IN (30, 40)
 ORDER BY id_departamento, salario;
-- Esperado (depto 30): 3600 -> 3600 | 6200 -> 9800 | 13500 -> 23300 (= total)

-- 4. ROWS versus RANGE com empate.
--    Ordenando por comissão, 104 e 105 empatam em 5. No ROWS, o id desempata
--    para o resultado ser reproduzível; no RANGE, o empate entra junto.
-- Esperado:
--   comissão 2: rows 2  | range 2
--   comissão 3: rows 5  | range 5
--   comissão 4: rows 9  | range 9
--   comissão 5: rows 14 | range 19   (primeira das duas linhas empatadas)
--   comissão 5: rows 19 | range 19
SELECT id_funcionario,
       pct_comissao,
       SUM(pct_comissao) OVER (ORDER BY pct_comissao, id_funcionario ROWS UNBOUNDED PRECEDING) AS acum_rows,
       SUM(pct_comissao) OVER (ORDER BY pct_comissao RANGE UNBOUNDED PRECEDING) AS acum_range
  FROM funcionarios
 WHERE pct_comissao IS NOT NULL
 ORDER BY pct_comissao, id_funcionario;

-- 5. Participação no total: divisão e RATIO_TO_REPORT.
-- Esperado: 108 49.65% | 106 25.20% | 104 10.79% | 105 8.69% | site 3.03% | 107 2.64%
WITH vendas AS (
    SELECT NVL(TO_CHAR(p.id_vendedor), 'site') AS vendedor,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS total
      FROM pedidos      p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
     GROUP BY p.id_vendedor
)
SELECT vendedor,
       total,
       ROUND(100 * total / SUM(total) OVER (), 2)        AS pct_divisao,
       ROUND(100 * RATIO_TO_REPORT(total) OVER (), 2)    AS pct_ratio
  FROM vendas
 ORDER BY total DESC;

-- 6. RANGE com intervalo de dias: valor vendido nos 90 dias anteriores a
--    cada pedido (inclusive), independentemente de quantos pedidos houve.
SELECT id_pedido,
       TO_CHAR(data_pedido, 'YYYY-MM-DD')   AS data,
       valor_pedido,
       SUM(valor_pedido) OVER (ORDER BY data_pedido
                               RANGE BETWEEN 90 PRECEDING AND CURRENT ROW) AS ultimos_90_dias,
       COUNT(*)          OVER (ORDER BY data_pedido
                               RANGE BETWEEN 90 PRECEDING AND CURRENT ROW) AS pedidos_90_dias
  FROM (SELECT p.id_pedido, p.data_pedido,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor_pedido
          FROM pedidos      p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO'
         GROUP BY p.id_pedido, p.data_pedido)
 ORDER BY data_pedido;

-- 7. Diferença para a média do grupo.
SELECT nome, cargo, salario,
       ROUND(salario - AVG(salario) OVER (PARTITION BY cargo), 2) AS diferenca_media_cargo
  FROM funcionarios
 WHERE cargo = 'Vendedor'
 ORDER BY salario DESC;
-- Esperado: média dos vendedores 4700 -> 5200 +500 | 4800 +100 | 4500 -200 | 4300 -400
