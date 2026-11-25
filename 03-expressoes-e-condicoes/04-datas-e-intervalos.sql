-- =============================================================================
-- Tópico : Expressões com datas e intervalos
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- As datas de referência são fixas para o resultado não depender do dia em
-- que o script roda.
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

-- 1. Somar dias, horas e minutos.
-- Esperado: 2026-11-26 00:00 | 2026-11-25 01:00 | 2026-11-25 00:30 | 2026-11-18 00:00
SELECT DATE '2026-11-25' + 1        AS mais_um_dia,
       DATE '2026-11-25' + 1/24     AS mais_uma_hora,
       DATE '2026-11-25' + 30/1440  AS mais_30_min,
       DATE '2026-11-25' - 7        AS menos_uma_semana
  FROM dual;

-- 2. Diferença entre datas: dias, horas.
--    Pedido 1001 (08/01/2025 09:15) até pedido 1006 (28/03/2025 11:00).
-- Esperado: 79.07 dias | 1897.75 horas
SELECT ROUND(p2.data_pedido - p1.data_pedido, 2)        AS dias,
       ROUND((p2.data_pedido - p1.data_pedido) * 24, 2) AS horas
  FROM pedidos p1, pedidos p2
 WHERE p1.id_pedido = 1001
   AND p2.id_pedido = 1006;

-- 3. Datas não se somam.
-- Esperado: ORA-00975 (data + data não é permitido)
SELECT DATE '2026-01-01' + DATE '2026-01-02' FROM dual;

-- 4. ADD_MONTHS e o fim do mês.
-- Esperado: 2026-02-28 | 2026-03-31 | 2026-03-15
SELECT ADD_MONTHS(DATE '2026-01-31', 1) AS jan31_mais_1,
       ADD_MONTHS(DATE '2026-02-28', 1) AS fev28_mais_1,
       ADD_MONTHS(DATE '2026-02-15', 1) AS fev15_mais_1
  FROM dual;

-- 5. INTERVAL MONTH não ajusta o dia.
-- Esperado: 2026-03-15
SELECT DATE '2026-02-15' + INTERVAL '1' MONTH AS ok FROM dual;

-- Esperado: ORA-01839 (data não válida para o mês especificado)
SELECT DATE '2026-01-31' + INTERVAL '1' MONTH AS erro FROM dual;

-- 6. TRUNC e LAST_DAY: início e fim de períodos.
-- Esperado: 2026-11-25 | 2026-11-01 | 2026-01-01 | 2026-11-30 | 2026-11-23 (segunda)
SELECT TRUNC(TIMESTAMP '2026-11-25 14:30:00')             AS dia,
       TRUNC(DATE '2026-11-25', 'MM')                      AS inicio_mes,
       TRUNC(DATE '2026-11-25', 'YYYY')                    AS inicio_ano,
       LAST_DAY(DATE '2026-11-25')                         AS fim_mes,
       TRUNC(DATE '2026-11-25', 'IW')                      AS segunda_da_semana
  FROM dual;

-- 7. Tempo de casa em anos completos em 31/12/2026.
-- Esperado: Ana 11, Bruno 10, Carla 9 ... Nelson 1
SELECT nome,
       data_admissao,
       TRUNC(MONTHS_BETWEEN(DATE '2026-12-31', data_admissao) / 12) AS anos_completos
  FROM funcionarios
 ORDER BY data_admissao;

-- 8. Intervalos: literais, conversão e extração.
-- Esperado: +00 01:30:00 | +01-06 | 1 dia e 2 horas
SELECT NUMTODSINTERVAL(90, 'MINUTE')                                AS noventa_min,
       NUMTOYMINTERVAL(18, 'MONTH')                                 AS dezoito_meses,
       EXTRACT(DAY  FROM (TIMESTAMP '2026-11-26 14:00:00' - TIMESTAMP '2026-11-25 12:00:00')) || ' dia e ' ||
       EXTRACT(HOUR FROM (TIMESTAMP '2026-11-26 14:00:00' - TIMESTAMP '2026-11-25 12:00:00')) || ' horas' AS diferenca
  FROM dual;

-- 9. Período relativo: pedidos do mês anterior a uma data de referência.
--    Com SYSDATE no lugar de DATE '2026-11-25', vira "o mês passado".
-- Esperado: 1023 e 1024 (outubro de 2026)
SELECT id_pedido, data_pedido
  FROM pedidos
 WHERE data_pedido >= ADD_MONTHS(TRUNC(DATE '2026-11-25', 'MM'), -1)
   AND data_pedido <  TRUNC(DATE '2026-11-25', 'MM')
 ORDER BY id_pedido;

-- 10. Dias entre pedidos consecutivos de cada cliente.
SELECT id_cliente,
       id_pedido,
       data_pedido,
       ROUND(data_pedido - LAG(data_pedido) OVER (PARTITION BY id_cliente ORDER BY data_pedido)) AS dias_desde_anterior
  FROM pedidos
 ORDER BY id_cliente, data_pedido;
