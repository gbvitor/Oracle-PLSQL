-- =============================================================================
-- Tópico : Funções numéricas
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. ROUND, TRUNC, CEIL e FLOOR com positivos e negativos.
-- Esperado:
--    2.5 ->  3 |  2 |  3 |  2
--    2.4 ->  2 |  2 |  3 |  2
--   -2.5 -> -3 | -2 | -2 | -3
--   -2.4 -> -2 | -2 | -2 | -3
SELECT n, ROUND(n) AS round_, TRUNC(n) AS trunc_, CEIL(n) AS ceil_, FLOOR(n) AS floor_
  FROM (SELECT 2.5 AS n FROM dual UNION ALL
        SELECT 2.4      FROM dual UNION ALL
        SELECT -2.5     FROM dual UNION ALL
        SELECT -2.4     FROM dual);

-- 2. Casas decimais e posições negativas.
-- Esperado: 2.35 | 2.34 | 1200 | 1300 | 1000
SELECT ROUND(2.345, 2)    AS round_2,
       TRUNC(2.349, 2)    AS trunc_2,
       ROUND(1234, -2)    AS centena,
       ROUND(1250, -2)    AS centena_meio,
       TRUNC(1999, -3)    AS milhar_cortado
  FROM dual;

-- 3. MOD e REMAINDER.
-- Esperado: 3 | -3 | -1 | 0 | -1
SELECT MOD(11, 4)        AS mod_pos,
       MOD(-11, 4)       AS mod_neg,
       REMAINDER(11, 4)  AS remainder_,
       MOD(-4, 2)        AS par_negativo,
       MOD(-3, 2)        AS impar_negativo
  FROM dual;

-- 4. Arredondar por linha versus arredondar o total: três linhas de 1/3.
-- Esperado: 1.00 | 0.99
SELECT ROUND(SUM(v), 2)        AS arredonda_total,
       SUM(ROUND(v, 2))        AS arredonda_linha
  FROM (SELECT 1/3 AS v FROM dual CONNECT BY LEVEL <= 3);

-- 5. Rateio de 100,00 em 3 parcelas, com a diferença na última.
-- Esperado: 33.33 | 33.33 | 33.34 (soma 100.00)
SELECT parcela,
       CASE WHEN parcela < 3
            THEN TRUNC(100 / 3, 2)
            ELSE 100 - TRUNC(100 / 3, 2) * 2
       END AS valor
  FROM (SELECT LEVEL AS parcela FROM dual CONNECT BY LEVEL <= 3);

-- 6. Potência: juros compostos de 1% ao mês por 12 meses sobre 1000.
-- Esperado: 1126.83
SELECT ROUND(1000 * POWER(1.01, 12), 2) AS montante FROM dual;

-- 7. WIDTH_BUCKET: histograma de salários em faixas de 5 mil até 25 mil.
-- Esperado: faixa 1 (0-5k) 6 | faixa 2 (5k-10k) 4 | faixa 3 (10k-15k) 3 | faixa 6 (>= 25k) 1
SELECT WIDTH_BUCKET(salario, 0, 25000, 5) AS faixa,
       MIN(salario)                        AS menor,
       MAX(salario)                        AS maior,
       COUNT(*)                            AS funcionarios
  FROM funcionarios
 GROUP BY WIDTH_BUCKET(salario, 0, 25000, 5)
 ORDER BY faixa;

-- 8. SIGN e ABS: variação de preço praticado em relação ao de tabela.
SELECT i.id_pedido, i.id_produto,
       i.preco_unitario                                AS praticado,
       p.preco_unitario                                AS tabela,
       ABS(i.preco_unitario - p.preco_unitario)        AS diferenca,
       DECODE(SIGN(i.preco_unitario - p.preco_unitario), -1, 'abaixo', 0, 'igual', 1, 'acima') AS situacao
  FROM itens_pedido i
  JOIN produtos     p ON p.id_produto = i.id_produto
 WHERE i.id_pedido IN (1001, 1008)
 ORDER BY i.id_pedido, i.nr_item;
