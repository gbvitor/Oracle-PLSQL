-- =============================================================================
-- Tópico : Funções de data e hora
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

-- 1. Data e hora atuais: servidor versus sessão.
SELECT SYSDATE           AS servidor,
       CURRENT_DATE      AS sessao,
       SYSTIMESTAMP      AS servidor_ts,
       SESSIONTIMEZONE   AS fuso_sessao,
       DBTIMEZONE        AS fuso_banco
  FROM dual;

-- 2. EXTRACT: ano, mês e dia em DATE; hora só em TIMESTAMP.
-- Esperado: 2026 | 11 | 25
SELECT EXTRACT(YEAR  FROM DATE '2026-11-25') AS ano,
       EXTRACT(MONTH FROM DATE '2026-11-25') AS mes,
       EXTRACT(DAY   FROM DATE '2026-11-25') AS dia
  FROM dual;

-- Esperado: ORA-30076 (campo de extração inválido para a origem de extração)
SELECT EXTRACT(HOUR FROM data_pedido) FROM pedidos WHERE id_pedido = 1024;

-- Esperado: 20 | 20
SELECT EXTRACT(HOUR FROM CAST(data_pedido AS TIMESTAMP)) AS com_cast,
       TO_NUMBER(TO_CHAR(data_pedido, 'HH24'))            AS com_to_char
  FROM pedidos
 WHERE id_pedido = 1024;

-- 3. Calendário.
-- Esperado: 2026-02-28 | 1 | 1.4516 | 2026-11-30 | 2026-10-01 | 2026-12-01
SELECT ADD_MONTHS(DATE '2026-01-31', 1)                             AS add_months_,
       MONTHS_BETWEEN(DATE '2026-03-31', DATE '2026-02-28')          AS fins_de_mes,
       ROUND(MONTHS_BETWEEN(DATE '2026-03-15', DATE '2026-02-01'), 4) AS com_fracao,
       LAST_DAY(DATE '2026-11-25')                                  AS last_day_,
       TRUNC(DATE '2026-11-25', 'Q')                                AS inicio_trimestre,
       ROUND(DATE '2026-11-16', 'MM')                               AS round_mes
  FROM dual;

-- 4. NEXT_DAY depende do idioma da sessão.
ALTER SESSION SET NLS_DATE_LANGUAGE = 'BRAZILIAN PORTUGUESE';

-- Esperado: 2026-11-30 (25/11/2026 é quarta-feira)
SELECT NEXT_DAY(DATE '2026-11-25', 'SEGUNDA') AS proxima_segunda FROM dual;

-- Esperado: ORA-01846 (dia da semana não válido)
SELECT NEXT_DAY(DATE '2026-11-25', 'MONDAY') AS proxima_segunda FROM dual;

-- Independente de idioma.
-- Esperado: 2026-11-30
SELECT TRUNC(DATE '2026-11-25', 'IW') + 7 AS proxima_segunda FROM dual;

ALTER SESSION SET NLS_DATE_LANGUAGE = 'AMERICAN';

-- 5. Pedidos por dia da semana, sem depender de NLS.
--    TRUNC(d) - TRUNC(d, 'IW') + 1 dá 1 = segunda ... 7 = domingo.
-- Esperado: seg 2 | ter 9 | qua 6 | qui 3 | sex 4
SELECT TRUNC(data_pedido) - TRUNC(data_pedido, 'IW') + 1                    AS dia_semana,
       TO_CHAR(data_pedido, 'DY', 'NLS_DATE_LANGUAGE = BRAZILIAN PORTUGUESE') AS nome,
       COUNT(*)                                                              AS pedidos
  FROM pedidos
 GROUP BY TRUNC(data_pedido) - TRUNC(data_pedido, 'IW') + 1,
          TO_CHAR(data_pedido, 'DY', 'NLS_DATE_LANGUAGE = BRAZILIAN PORTUGUESE')
 ORDER BY dia_semana;

-- 6. Pedidos por período do dia.
-- Esperado: manha 11 | tarde 10 | noite 3
SELECT CASE
           WHEN TO_NUMBER(TO_CHAR(data_pedido, 'HH24')) < 12 THEN '1. manha'
           WHEN TO_NUMBER(TO_CHAR(data_pedido, 'HH24')) < 18 THEN '2. tarde'
           ELSE '3. noite'
       END       AS periodo,
       COUNT(*)  AS pedidos
  FROM pedidos
 GROUP BY CASE
              WHEN TO_NUMBER(TO_CHAR(data_pedido, 'HH24')) < 12 THEN '1. manha'
              WHEN TO_NUMBER(TO_CHAR(data_pedido, 'HH24')) < 18 THEN '2. tarde'
              ELSE '3. noite'
          END
 ORDER BY periodo;

-- 7. Fuso horário: meio-dia em São Paulo, em UTC e em Lisboa.
-- Esperado: 15:00 UTC | 15:00 Lisboa (novembro, sem horário de verão)
SELECT FROM_TZ(TIMESTAMP '2026-11-25 12:00:00', 'America/Sao_Paulo')                         AS sao_paulo,
       SYS_EXTRACT_UTC(FROM_TZ(TIMESTAMP '2026-11-25 12:00:00', 'America/Sao_Paulo'))        AS utc,
       FROM_TZ(TIMESTAMP '2026-11-25 12:00:00', 'America/Sao_Paulo') AT TIME ZONE 'Europe/Lisbon' AS lisboa,
       TZ_OFFSET('America/Sao_Paulo')                                                       AS deslocamento
  FROM dual;
