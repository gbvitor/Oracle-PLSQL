-- =============================================================================
-- Tópico : Tipos de dados — comportamento na prática
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : usuário com CREATE TABLE
-- Cria a tabela tmp_tipos e a remove no fim. Erros nos passos 3 e 4 são
-- intencionais.
-- =============================================================================

CREATE TABLE tmp_tipos (
    id            NUMBER(3),
    valor         NUMBER(5,2),
    centena       NUMBER(6,-2),
    texto_byte    VARCHAR2(5 BYTE),
    texto_char    VARCHAR2(5 CHAR),
    codigo_fixo   CHAR(5),
    momento_date  DATE,
    momento_ts    TIMESTAMP(6)
);

-- 1. NUMBER(5,2) arredonda casas decimais excedentes sem erro.
--    NUMBER(6,-2) arredonda para a centena.
INSERT INTO tmp_tipos (id, valor, centena) VALUES (1, 123.456, 123456);

-- Esperado: 123.46 | 123500
SELECT valor, centena FROM tmp_tipos WHERE id = 1;

-- 2. Texto: bytes versus caracteres.
--    UNISTR monta 'acao' com cedilha e til sem depender da codificação do
--    cliente: a\00E7\00E3o = "ação".
SELECT LENGTH(UNISTR('a\00E7\00E3o'))  AS caracteres,
       LENGTHB(UNISTR('a\00E7\00E3o')) AS bytes          -- 6 num banco AL32UTF8
  FROM dual;

-- 3. Cabe em VARCHAR2(5 CHAR), mas não em VARCHAR2(5 BYTE) se passar de 5 bytes.
-- ok
INSERT INTO tmp_tipos (id, texto_char) VALUES (2, UNISTR('a\00E7\00E3o'));

-- Esperado em banco AL32UTF8: ORA-12899 (valor grande demais: real 7, máximo 5)
INSERT INTO tmp_tipos (id, texto_byte) VALUES (3, UNISTR('a\00E7\00E3os'));

-- 4. Parte inteira maior que a precisão: erro.
-- Esperado: ORA-01438
INSERT INTO tmp_tipos (id, valor) VALUES (4, 1234.5);

-- 5. String vazia é NULL.
INSERT INTO tmp_tipos (id, texto_char) VALUES (5, '');

-- Esperado: situacao = nulo
SELECT id,
       texto_char,
       CASE WHEN texto_char IS NULL THEN 'nulo' ELSE 'nao nulo' END AS situacao
  FROM tmp_tipos
 WHERE id = 5;

-- Esperado: 0 (comparação com NULL)
SELECT COUNT(*) FROM tmp_tipos WHERE texto_char = '';

-- 6. CHAR completa com espaços. DUMP mostra o conteúdo gravado byte a byte.
INSERT INTO tmp_tipos (id, codigo_fixo) VALUES (6, 'SP');

SELECT codigo_fixo,
       LENGTH(codigo_fixo) AS tamanho,                -- 5
       DUMP(codigo_fixo)   AS conteudo                -- ...,83,80,32,32,32
  FROM tmp_tipos
 WHERE id = 6;

-- CHAR comparado com literal: completa com espaços, encontra.
-- Esperado: 1
SELECT COUNT(*) AS com_literal
  FROM tmp_tipos
 WHERE codigo_fixo = 'SP';

-- CHAR comparado com VARCHAR2: não completa, não encontra.
-- Esperado: 0
SELECT COUNT(*) AS com_varchar2
  FROM tmp_tipos
 WHERE codigo_fixo = CAST('SP' AS VARCHAR2(5));

-- 7. DATE tem hora; TIMESTAMP tem fração de segundo.
INSERT INTO tmp_tipos (id, momento_date, momento_ts) VALUES (7, SYSDATE, SYSTIMESTAMP);

SELECT TO_CHAR(momento_date, 'YYYY-MM-DD HH24:MI:SS')      AS data_completa,
       TO_CHAR(momento_ts,   'YYYY-MM-DD HH24:MI:SS.FF6')  AS timestamp_completo
  FROM tmp_tipos
 WHERE id = 7;

-- 8. Aritmética de datas.
SELECT DATE '2026-03-01' - DATE '2026-02-01'                       AS dias_entre_datas,   -- 28
       TIMESTAMP '2026-03-01 12:00:00' - TIMESTAMP '2026-02-01 00:00:00' AS intervalo,     -- +28 12:00:00
       DATE '2026-01-31' + 1                                       AS dia_seguinte,
       TO_CHAR(DATE '2026-01-31' + 6/24, 'YYYY-MM-DD HH24:MI')     AS mais_seis_horas      -- 2026-01-31 06:00
  FROM dual;

-- 9. Tipo e tamanho de cada coluna, lidos do dicionário.
--    char_used: B = semântica de bytes, C = de caracteres.
SELECT column_name, data_type, data_length, data_precision, data_scale, char_used
  FROM user_tab_columns
 WHERE table_name = 'TMP_TIPOS'
 ORDER BY column_id;

-- Limpeza
ROLLBACK;
DROP TABLE tmp_tipos PURGE;
