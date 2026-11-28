-- =============================================================================
-- Tópico : Parâmetros e NLS — o que mudou do padrão, camadas NLS, idioma e
--          separadores, semântica de bytes, ordenação e comparação linguística
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); SELECT_CATALOG_ROLE para V$PARAMETER.
--          As alterações são de sessão; nada muda para outras sessões.
-- =============================================================================

SET LINESIZE 200
COLUMN name      FORMAT A32
COLUMN value     FORMAT A40
COLUMN parameter FORMAT A26

-- 1. Parâmetros alterados em relação ao padrão (o que alguém configurou de propósito).
SELECT name, value, issys_modifiable, isses_modifiable
  FROM v$parameter
 WHERE isdefault = 'FALSE'
 ORDER BY name;

-- Os que a sessão pode mudar sozinha, entre os mais úteis.
-- Esperado: TRUE para todos (são de sessão)
SELECT name, value, isses_modifiable
  FROM v$parameter
 WHERE name IN ('nls_date_format', 'optimizer_mode', 'ddl_lock_timeout', 'statistics_level', 'cursor_sharing')
 ORDER BY name;

-- 2. As três camadas de NLS, para o formato de data.
-- Esperado: banco DD-MON-RR | instância (vazio ou igual) | sessão: o que o cliente definiu
SELECT 'banco' AS camada, value FROM nls_database_parameters WHERE parameter = 'NLS_DATE_FORMAT'
UNION ALL
SELECT 'instância', value FROM nls_instance_parameters WHERE parameter = 'NLS_DATE_FORMAT'
UNION ALL
SELECT 'sessão', value FROM nls_session_parameters WHERE parameter = 'NLS_DATE_FORMAT';

-- Character set do banco.
-- Esperado: AL32UTF8 | AL16UTF16 (no container Free)
SELECT parameter, value
  FROM nls_database_parameters
 WHERE parameter IN ('NLS_CHARACTERSET', 'NLS_NCHAR_CHARACTERSET', 'NLS_LENGTH_SEMANTICS');

-- 3. Idioma e território da sessão.
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_TERRITORY = 'AMERICA';

-- Esperado: Friday   , November  | 1,234.56 (Day e Month completam com espaços; fmDay tira)
SELECT TO_CHAR(DATE '2026-11-27', 'Day, Month') AS data_por_extenso,
       TO_CHAR(1234.56, '9G999D99')             AS numero
  FROM dual;

ALTER SESSION SET NLS_LANGUAGE = 'BRAZILIAN PORTUGUESE';
ALTER SESSION SET NLS_TERRITORY = 'BRAZIL';

-- Esperado: Sexta-Feira, Novembro | 1.234,56 (com espaços de preenchimento)
SELECT TO_CHAR(DATE '2026-11-27', 'Day, Month') AS data_por_extenso,
       TO_CHAR(1234.56, '9G999D99')             AS numero
  FROM dual;

-- A função vence a sessão: o resultado independe do NLS de quem executa.
-- Esperado: Friday | 1234.56 (mesmo com a sessão em português)
SELECT TO_CHAR(DATE '2026-11-27', 'fmDay', 'NLS_DATE_LANGUAGE = AMERICAN') AS dia,
       TO_CHAR(1234.56, 'FM9999D99', 'NLS_NUMERIC_CHARACTERS = ''.,''')    AS numero
  FROM dual;

-- Código que depende do NLS da sessão quebra quando o cliente muda.
-- Esperado: funciona só se o NLS_DATE_FORMAT da sessão for DD/MM/YYYY; senão, ORA-01843 ou ORA-01861
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';
SELECT TO_DATE('27/11/2026') FROM dual;

-- Esperado: 27/11/2026, independente da sessão
SELECT TO_CHAR(TO_DATE('27/11/2026', 'DD/MM/YYYY'), 'DD/MM/YYYY') AS data FROM dual;

-- 4. Semântica de bytes e caracteres.
CREATE TABLE tmp_nls (
    em_bytes      VARCHAR2(4 BYTE),
    em_caracteres VARCHAR2(4 CHAR)
);

-- Esperado: 1 linha (cabe nos dois)
INSERT INTO tmp_nls VALUES ('acao', 'acao');

-- Esperado: ORA-12899 (valor muito grande para a coluna EM_BYTES: real 5, máximo 4)
INSERT INTO tmp_nls VALUES ('ação', 'ação');

-- Esperado: 1 linha (só a coluna em caracteres recebe o texto acentuado)
INSERT INTO tmp_nls (em_caracteres) VALUES ('ação');

-- Esperado: ação | 4 caracteres | 5 bytes (em AL32UTF8)
SELECT em_caracteres, LENGTH(em_caracteres) AS caracteres, LENGTHB(em_caracteres) AS bytes
  FROM tmp_nls
 WHERE em_bytes IS NULL;

ROLLBACK;
DROP TABLE tmp_nls PURGE;

-- 5. Ordenação e comparação.
CREATE TABLE tmp_palavras (palavra VARCHAR2(20 CHAR));
INSERT INTO tmp_palavras VALUES ('Zebra');
INSERT INTO tmp_palavras VALUES ('abacaxi');
INSERT INTO tmp_palavras VALUES ('Ábaco');
INSERT INTO tmp_palavras VALUES ('água');
COMMIT;

-- Binária (padrão): pelo código do caractere.
ALTER SESSION SET NLS_SORT = BINARY;
-- Esperado: Zebra | abacaxi | Ábaco | água
SELECT palavra FROM tmp_palavras ORDER BY palavra;

-- Ignorando maiúsculas e acentos.
ALTER SESSION SET NLS_SORT = BINARY_AI;
-- Esperado: abacaxi | Ábaco | água | Zebra
SELECT palavra FROM tmp_palavras ORDER BY palavra;

-- O NLS_SORT sozinho não muda o "=": é preciso NLS_COMP = LINGUISTIC.
-- Esperado: 0
SELECT COUNT(*) FROM tmp_palavras WHERE palavra = 'agua';

ALTER SESSION SET NLS_COMP = LINGUISTIC;
-- Esperado: 1 (água)
SELECT COUNT(*) FROM tmp_palavras WHERE palavra = 'agua';

-- Sem depender da sessão: a regra na própria consulta, com NLSSORT.
ALTER SESSION SET NLS_COMP = BINARY;
ALTER SESSION SET NLS_SORT = BINARY;
-- Esperado: 1
SELECT COUNT(*)
  FROM tmp_palavras
 WHERE NLSSORT(palavra, 'NLS_SORT = BINARY_AI') = NLSSORT('agua', 'NLS_SORT = BINARY_AI');
-- (o índice que serve a esta condição é CREATE INDEX ... ON tmp_palavras
--  (NLSSORT(palavra, 'NLS_SORT = BINARY_AI')))

DROP TABLE tmp_palavras PURGE;

-- 6. [DBA] Alterar parâmetro da instância (não rode no ambiente compartilhado sem combinar):
--   ALTER SYSTEM SET open_cursors = 500 SCOPE = BOTH;
--   SELECT name, value FROM v$spparameter WHERE name = 'open_cursors';
--   Esperado: 500 em V$PARAMETER e em V$SPPARAMETER
