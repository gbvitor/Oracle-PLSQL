-- =============================================================================
-- Tópico : Funções de conversão e máscaras de formato
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Os separadores e nomes dependem dos parâmetros NLS; os primeiros comandos
-- fixam um padrão brasileiro para os resultados esperados valerem.
-- =============================================================================

ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';
ALTER SESSION SET NLS_DATE_LANGUAGE      = 'BRAZILIAN PORTUGUESE';
ALTER SESSION SET NLS_CURRENCY           = 'R$';

-- 1. Data para texto em vários formatos.
--    Referência: pedido 1024, 30/10/2026 20:30 (sexta-feira).
-- Esperado: 30/10/2026 | 30/10/2026 20:30:00 | 30 de outubro de 2026 | SEX | 4o trimestre
SELECT TO_CHAR(data_pedido, 'DD/MM/YYYY')                  AS data_br,
       TO_CHAR(data_pedido, 'DD/MM/YYYY HH24:MI:SS')       AS data_hora,
       TO_CHAR(data_pedido, 'FMDD "de" month "de" YYYY')   AS por_extenso,
       TO_CHAR(data_pedido, 'DY')                          AS dia_semana,
       TO_CHAR(data_pedido, 'Q') || 'o trimestre'          AS trimestre
  FROM pedidos
 WHERE id_pedido = 1024;

-- 2. FM remove espaços e zeros à esquerda.
-- Esperado: [05/03/2026] | [5/3/2026] | [MARCO    ] | [MARCO]
SELECT '[' || TO_CHAR(DATE '2026-03-05', 'DD/MM/YYYY')   || ']' AS sem_fm,
       '[' || TO_CHAR(DATE '2026-03-05', 'FMDD/MM/YYYY') || ']' AS com_fm,
       '[' || TO_CHAR(DATE '2026-03-05', 'MONTH')        || ']' AS mes_sem_fm,
       '[' || TO_CHAR(DATE '2026-03-05', 'FMMONTH')      || ']' AS mes_com_fm
  FROM dual;
-- O nome do mês sai acentuado (MARÇO) se o cliente exibir UTF-8.

-- 3. MM no lugar de MI: o mês aparece onde deveria estar o minuto.
-- Esperado: 20:10 (errado, 10 = outubro) | 20:30 (certo)
SELECT TO_CHAR(data_pedido, 'HH24:MM') AS errado,
       TO_CHAR(data_pedido, 'HH24:MI') AS certo
  FROM pedidos
 WHERE id_pedido = 1024;

-- 4. Número para texto.
-- Esperado: [   42] | [ 0042] | [42] | [1.234,50] | [R$1.234,50] | [FF] | [####]
SELECT '[' || TO_CHAR(42, '9999')               || ']' AS nove,
       '[' || TO_CHAR(42, '0000')               || ']' AS zero,
       '[' || TO_CHAR(42, 'FM9999')             || ']' AS fm,
       '[' || TO_CHAR(1234.5, 'FM9G999D00')     || ']' AS milhar_decimal,
       '[' || TO_CHAR(1234.5, 'FML9G999D00')    || ']' AS moeda,
       '[' || TO_CHAR(255, 'FMXX')              || ']' AS hexadecimal,
       '[' || TO_CHAR(12345, 'FM999')           || ']' AS nao_cabe
  FROM dual;

-- Valor de pedidos formatado para relatório.
SELECT p.id_pedido,
       TO_CHAR(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)),
               'FML999G999G990D00') AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.id_pedido IN (1001, 1008)
 GROUP BY p.id_pedido
 ORDER BY p.id_pedido;
-- Esperado: 1001 R$1.045,50 | 1008 R$27.286,00

-- 5. Texto para data e número.
-- Esperado: 2026-11-25 14:05:00 | 1234,56 | 1234,56
SELECT TO_CHAR(TO_DATE('25/11/2026 14:05', 'DD/MM/YYYY HH24:MI'), 'YYYY-MM-DD HH24:MI:SS') AS data_lida,
       TO_NUMBER('1.234,56', '9G999D99')                                              AS numero_br,
       TO_NUMBER('1,234.56', '9,999.99')                                              AS numero_us
  FROM dual;

-- Parâmetro NLS na própria chamada: funciona em qualquer sessão.
-- Esperado: 1234,56
SELECT TO_NUMBER('1.234,56', '9G999D99', 'NLS_NUMERIC_CHARACTERS = '',.''') AS independente
  FROM dual;

-- 6. YY versus RR ao ler ano com dois dígitos.
-- Esperado: 2050 | 1950 | 2049 | 2049
SELECT TO_CHAR(TO_DATE('01/01/50', 'DD/MM/YY'), 'YYYY') AS yy_50,
       TO_CHAR(TO_DATE('01/01/50', 'DD/MM/RR'), 'YYYY') AS rr_50,
       TO_CHAR(TO_DATE('01/01/49', 'DD/MM/YY'), 'YYYY') AS yy_49,
       TO_CHAR(TO_DATE('01/01/49', 'DD/MM/RR'), 'YYYY') AS rr_49
  FROM dual;

-- 7. FX exige formato exato.
-- Esperado: aceita '5/3/2026' sem FX
SELECT TO_DATE('5/3/2026', 'DD/MM/YYYY') AS tolerante FROM dual;

-- Esperado: erro com FX (o dia precisa ter dois dígitos)
SELECT TO_DATE('5/3/2026', 'FXDD/MM/YYYY') AS exato FROM dual;

-- 8. HH vai de 1 a 12.
-- Esperado: ORA-01849 (a hora deve estar entre 1 e 12)
SELECT TO_DATE('14:00', 'HH:MI') FROM dual;

-- 9. Conversão tolerante a erro [12.2+]: dados "importados" com sujeira.
WITH importados AS (
    SELECT '1.234,56'   AS valor_txt, '25/11/2026' AS data_txt FROM dual UNION ALL
    SELECT '99,90',                   '31/02/2026'           FROM dual UNION ALL
    SELECT 'R$ 10',                   '2026-11-25'           FROM dual UNION ALL
    SELECT NULL,                      '01/01/2027'           FROM dual
)
SELECT valor_txt,
       TO_NUMBER(valor_txt DEFAULT NULL ON CONVERSION ERROR, '9G999D99')   AS valor,
       VALIDATE_CONVERSION(valor_txt AS NUMBER, '9G999D99')                AS valor_ok,
       data_txt,
       TO_DATE(data_txt DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY')    AS data,
       VALIDATE_CONVERSION(data_txt AS DATE, 'DD/MM/YYYY')                 AS data_ok
  FROM importados;
-- valor_ok: 1, 1, 0, 1 (NULL é considerado conversível)
-- data_ok : 1, 0 (31/02 não existe), 0 (formato diferente), 1

-- 10. CAST.
-- Esperado: 42 | 2026-11-25 00:00:00 | 0
SELECT CAST('42' AS NUMBER)                                  AS texto_numero,
       CAST(DATE '2026-11-25' AS TIMESTAMP)                  AS data_timestamp,
       CAST('abc' AS NUMBER DEFAULT 0 ON CONVERSION ERROR)   AS com_padrao
  FROM dual;

-- Restaurar padrão americano na sessão.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
ALTER SESSION SET NLS_DATE_LANGUAGE      = 'AMERICAN';
