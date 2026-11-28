-- =============================================================================
-- Caso   : Calendário — gerar dias, série diária com zeros, grade semanal,
--          dias úteis e prazo em dias úteis
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- 1. Os dias de outubro/2026.
-- Esperado: 31 linhas, de 01/10/2026 a 31/10/2026
SELECT DATE '2026-10-01' + LEVEL - 1 AS dia
  FROM dual
CONNECT BY LEVEL <= LAST_DAY(DATE '2026-10-01') - DATE '2026-10-01' + 1;

-- A mesma lista com CTE recursiva [11gR2+].
-- Esperado: 31
WITH dias (dia) AS (
    SELECT DATE '2026-10-01' FROM dual
    UNION ALL
    SELECT dia + 1 FROM dias WHERE dia < DATE '2026-10-31'
)
SELECT COUNT(*) FROM dias;

-- 2. Série diária de vendas com zero nos dias sem pedido.
WITH dias AS (
    SELECT DATE '2026-10-01' + LEVEL - 1 AS dia
      FROM dual
    CONNECT BY LEVEL <= 31
),
vendas AS (
    SELECT TRUNC(p.data_pedido) AS dia,
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.status <> 'CANCELADO'
       AND p.data_pedido >= DATE '2026-10-01'
       AND p.data_pedido <  DATE '2026-11-01'
     GROUP BY TRUNC(p.data_pedido)
)
SELECT d.dia,
       TO_CHAR(d.dia, 'DY', 'NLS_DATE_LANGUAGE=PORTUGUESE') AS dsem,
       NVL(v.valor, 0)                                     AS valor,
       SUM(NVL(v.valor, 0)) OVER (ORDER BY d.dia)          AS acumulado
  FROM dias d
  LEFT JOIN vendas v ON v.dia = d.dia
 ORDER BY d.dia;
-- Esperado: 31 linhas; 14/10 com 899, 30/10 com 3150, os outros 29 dias com 0;
--           acumulado 0 até 13/10, 899 de 14/10 a 29/10, 4049 em 30/10 e 31/10

-- Só a contagem de dias sem movimento.
-- Esperado: 29
WITH dias AS (
    SELECT DATE '2026-10-01' + LEVEL - 1 AS dia FROM dual CONNECT BY LEVEL <= 31
)
SELECT COUNT(*) AS dias_sem_pedido
  FROM dias d
 WHERE NOT EXISTS (SELECT 1
                     FROM pedidos p
                    WHERE p.status <> 'CANCELADO'
                      AND p.data_pedido >= d.dia
                      AND p.data_pedido <  d.dia + 1);

-- 3. Grade do mês: uma linha por semana, uma coluna por dia (segunda a domingo).
WITH dias AS (
    SELECT DATE '2026-10-01' + LEVEL - 1 AS dia FROM dual CONNECT BY LEVEL <= 31
)
SELECT TRUNC(dia, 'IW') AS semana,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 0 THEN EXTRACT(DAY FROM dia) END) AS seg,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 1 THEN EXTRACT(DAY FROM dia) END) AS ter,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 2 THEN EXTRACT(DAY FROM dia) END) AS qua,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 3 THEN EXTRACT(DAY FROM dia) END) AS qui,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 4 THEN EXTRACT(DAY FROM dia) END) AS sex,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 5 THEN EXTRACT(DAY FROM dia) END) AS sab,
       MAX(CASE dia - TRUNC(dia, 'IW') WHEN 6 THEN EXTRACT(DAY FROM dia) END) AS dom
  FROM dias
 GROUP BY TRUNC(dia, 'IW')
 ORDER BY semana;
-- Esperado: 5 linhas
--   28/09/2026 | -  | -  | -  | 1  | 2  | 3  | 4
--   05/10/2026 | 5  | 6  | 7  | 8  | 9  | 10 | 11
--   12/10/2026 | 12 | 13 | 14 | 15 | 16 | 17 | 18
--   19/10/2026 | 19 | 20 | 21 | 22 | 23 | 24 | 25
--   26/10/2026 | 26 | 27 | 28 | 29 | 30 | 31 | -

-- 4. Feriados (nacionais de outubro a dezembro de 2026).
CREATE TABLE tmp_feriados (
    dt_feriado DATE          CONSTRAINT pk_tmp_feriados PRIMARY KEY,
    descricao  VARCHAR2(60)  NOT NULL
);

INSERT INTO tmp_feriados VALUES (DATE '2026-10-12', 'Nossa Senhora Aparecida');
INSERT INTO tmp_feriados VALUES (DATE '2026-11-02', 'Finados');
INSERT INTO tmp_feriados VALUES (DATE '2026-11-15', 'Proclamação da República');
INSERT INTO tmp_feriados VALUES (DATE '2026-11-20', 'Consciência Negra');
INSERT INTO tmp_feriados VALUES (DATE '2026-12-25', 'Natal');
COMMIT;

-- Dias úteis por mês.
-- Esperado: 2026-10 31 9 1 21 | 2026-11 30 9 2 19
WITH dias AS (
    SELECT DATE '2026-10-01' + LEVEL - 1 AS dia
      FROM dual
    CONNECT BY LEVEL <= DATE '2026-11-30' - DATE '2026-10-01' + 1
)
SELECT TO_CHAR(d.dia, 'YYYY-MM') AS mes,
       COUNT(*) AS dias,
       COUNT(CASE WHEN d.dia - TRUNC(d.dia, 'IW') >= 5 THEN 1 END) AS fim_de_semana,
       COUNT(CASE WHEN d.dia - TRUNC(d.dia, 'IW') < 5
                   AND f.dt_feriado IS NOT NULL THEN 1 END) AS feriado_util,
       COUNT(CASE WHEN d.dia - TRUNC(d.dia, 'IW') < 5
                   AND f.dt_feriado IS NULL THEN 1 END) AS uteis
  FROM dias d
  LEFT JOIN tmp_feriados f ON f.dt_feriado = d.dia
 GROUP BY TO_CHAR(d.dia, 'YYYY-MM')
 ORDER BY mes;

-- 5. Prazo: data do pedido + 5 dias úteis.
WITH dias AS (
    SELECT DATE '2026-10-01' + LEVEL - 1 AS dia FROM dual CONNECT BY LEVEL <= 92
),
uteis AS (
    SELECT dia
      FROM dias
     WHERE dia - TRUNC(dia, 'IW') < 5
       AND dia NOT IN (SELECT dt_feriado FROM tmp_feriados)
)
SELECT id_pedido, data_pedido, dia AS prazo
  FROM (SELECT p.id_pedido,
               TRUNC(p.data_pedido) AS data_pedido,
               u.dia,
               ROW_NUMBER() OVER (PARTITION BY p.id_pedido ORDER BY u.dia) AS rn
          FROM pedidos p
          JOIN uteis u ON u.dia > TRUNC(p.data_pedido)
         WHERE p.id_pedido IN (1023, 1024))
 WHERE rn = 5
 ORDER BY id_pedido;
-- Esperado: 1023 14/10/2026 21/10/2026
--           1024 30/10/2026 09/11/2026   (02/11 é feriado)

-- Dias úteis entre duas datas (exclui a inicial, inclui a final).
-- Esperado: 17
WITH dias AS (
    SELECT DATE '2026-10-14' + LEVEL AS dia
      FROM dual
    CONNECT BY LEVEL <= DATE '2026-11-09' - DATE '2026-10-14'
)
SELECT COUNT(*) AS dias_uteis
  FROM dias
 WHERE dia - TRUNC(dia, 'IW') < 5
   AND dia NOT IN (SELECT dt_feriado FROM tmp_feriados);

-- 6. Tabela de calendário (dimensão de tempo), gerada uma vez.
CREATE TABLE tmp_calendario AS
SELECT d.dia,
       EXTRACT(YEAR  FROM d.dia)                  AS ano,
       EXTRACT(MONTH FROM d.dia)                  AS mes,
       d.dia - TRUNC(d.dia, 'IW') + 1             AS dia_semana_iso,
       TO_NUMBER(TO_CHAR(d.dia, 'IW'))            AS semana_iso,
       CASE WHEN d.dia - TRUNC(d.dia, 'IW') < 5 AND f.dt_feriado IS NULL
            THEN 'S' ELSE 'N' END                 AS util,
       f.descricao                                AS feriado
  FROM (SELECT DATE '2025-01-01' + LEVEL - 1 AS dia
          FROM dual
        CONNECT BY LEVEL <= DATE '2026-12-31' - DATE '2025-01-01' + 1) d
  LEFT JOIN tmp_feriados f ON f.dt_feriado = d.dia;

ALTER TABLE tmp_calendario ADD CONSTRAINT pk_tmp_calendario PRIMARY KEY (dia);

-- Esperado: 730
SELECT COUNT(*) FROM tmp_calendario;

-- Com a tabela, a consulta de dias úteis fica simples.
-- Esperado: 21
SELECT COUNT(*) FROM tmp_calendario WHERE ano = 2026 AND mes = 10 AND util = 'S';

-- Os feriados só valem de outubro a dezembro de 2026 neste exemplo:
-- num sistema real, a tabela de feriados cobre todo o período do calendário.

DROP TABLE tmp_calendario PURGE;
DROP TABLE tmp_feriados PURGE;
