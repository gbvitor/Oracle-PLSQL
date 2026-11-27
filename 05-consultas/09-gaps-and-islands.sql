-- =============================================================================
-- Tópico : Lacunas e sequências (gaps and islands)
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Ilhas: períodos de meses seguidos com venda (sem cancelados).
--    Índice do mês = ano * 12 + mês; índice - ROW_NUMBER é constante na ilha.
-- Esperado: 5 ilhas
--   2025-01 a 2025-03  (3 meses)
--   2025-05 a 2026-02  (10 meses)
--   2026-04            (1)
--   2026-06            (1)
--   2026-08 a 2026-10  (3)
WITH meses AS (
    SELECT DISTINCT
           EXTRACT(YEAR FROM data_pedido) * 12 + EXTRACT(MONTH FROM data_pedido) AS idx,
           TO_CHAR(data_pedido, 'YYYY-MM')                                       AS mes
      FROM pedidos
     WHERE status <> 'CANCELADO'
)
SELECT MIN(mes) AS inicio,
       MAX(mes) AS fim,
       COUNT(*) AS meses
  FROM (SELECT idx, mes, idx - ROW_NUMBER() OVER (ORDER BY idx) AS grupo
          FROM meses)
 GROUP BY grupo
 ORDER BY inicio;

-- 2. Lacunas: meses sem venda entre o primeiro e o último.
-- Esperado: 2025-04, 2026-03, 2026-05, 2026-07
WITH meses AS (
    SELECT DISTINCT
           EXTRACT(YEAR FROM data_pedido) * 12 + EXTRACT(MONTH FROM data_pedido) AS idx
      FROM pedidos
     WHERE status <> 'CANCELADO'
)
--    Para voltar do índice ao mês: janeiro de 2000 tem índice 2000 * 12 + 1 = 24001,
--    então o mês de índice k é ADD_MONTHS(DATE '2000-01-01', k - 24001).
SELECT TO_CHAR(ADD_MONTHS(DATE '2000-01-01', idx + 1     - 24001), 'YYYY-MM') AS lacuna_inicio,
       TO_CHAR(ADD_MONTHS(DATE '2000-01-01', proximo - 1 - 24001), 'YYYY-MM') AS lacuna_fim
  FROM (SELECT idx, LEAD(idx) OVER (ORDER BY idx) AS proximo FROM meses)
 WHERE proximo - idx > 1
 ORDER BY idx;

-- 3. Lacunas em numeração: série de números de nota com saltos.
CREATE TABLE tmp_notas (numero NUMBER PRIMARY KEY);
INSERT INTO tmp_notas SELECT LEVEL FROM dual CONNECT BY LEVEL <= 20;
DELETE FROM tmp_notas WHERE numero IN (5, 6, 12, 19);
COMMIT;

-- Esperado: 5-6 | 12-12 | 19-19
SELECT numero + 1  AS falta_de,
       proximo - 1 AS falta_ate
  FROM (SELECT numero, LEAD(numero) OVER (ORDER BY numero) AS proximo FROM tmp_notas)
 WHERE proximo - numero > 1
 ORDER BY numero;

-- Ilhas da mesma série.
-- Esperado: 1-4 | 7-11 | 13-18 | 20-20
SELECT MIN(numero) AS de, MAX(numero) AS ate, COUNT(*) AS notas
  FROM (SELECT numero, numero - ROW_NUMBER() OVER (ORDER BY numero) AS grupo FROM tmp_notas)
 GROUP BY grupo
 ORDER BY de;

DROP TABLE tmp_notas PURGE;

-- 4. Ilhas de datas diárias: DATE - ROW_NUMBER direto.
--    Dias com o equipamento parado (dados de teste).
-- Esperado: 03/11 a 05/11 (3 dias) | 10/11 a 11/11 (2) | 20/11 (1)
WITH paradas AS (
    SELECT DATE '2026-11-03' + LEVEL - 1 AS dia FROM dual CONNECT BY LEVEL <= 3 UNION ALL
    SELECT DATE '2026-11-10' FROM dual UNION ALL
    SELECT DATE '2026-11-11' FROM dual UNION ALL
    SELECT DATE '2026-11-20' FROM dual
)
SELECT TO_CHAR(MIN(dia), 'DD/MM') AS inicio,
       TO_CHAR(MAX(dia), 'DD/MM') AS fim,
       COUNT(*)                   AS dias
  FROM (SELECT dia, dia - ROW_NUMBER() OVER (ORDER BY dia) AS grupo FROM paradas)
 GROUP BY grupo
 ORDER BY MIN(dia);

-- 5. Ilhas por mudança de estado: períodos com o mesmo status.
--    Histórico de status de um equipamento (dados de teste).
-- Esperado: 3 trechos
--   1: OPERANDO 01/11 a 03/11 | 2: PARADO 04/11 a 05/11 | 3: OPERANDO 06/11 a 08/11
WITH historico AS (
    SELECT DATE '2026-11-01' + LEVEL - 1 AS dia,
           CASE WHEN LEVEL IN (4, 5) THEN 'PARADO' ELSE 'OPERANDO' END AS status
      FROM dual CONNECT BY LEVEL <= 8
),
marcado AS (
    SELECT dia, status,
           CASE WHEN status = LAG(status) OVER (ORDER BY dia) THEN 0 ELSE 1 END AS mudou
      FROM historico
),
trechos AS (
    SELECT dia, status,
           SUM(mudou) OVER (ORDER BY dia ROWS UNBOUNDED PRECEDING) AS trecho
      FROM marcado
)
SELECT trecho, status,
       TO_CHAR(MIN(dia), 'DD/MM') AS inicio,
       TO_CHAR(MAX(dia), 'DD/MM') AS fim,
       COUNT(*)                   AS dias
  FROM trechos
 GROUP BY trecho, status
 ORDER BY trecho;
