-- =============================================================================
-- Tópico : Controle de erro em script — o padrão (segue em frente),
--          WHENEVER SQLERROR, compilação com erro, SET ERRORLOGGING
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus)
-- Requer : schema de exemplo (00-ambiente)
--
-- Os exemplos com EXIT encerrariam a sessão de estudo: ficam descritos em
-- comentário, com o resultado esperado. O resto roda com CONTINUE.
-- =============================================================================

-- 1. O padrão: o erro aparece e o script continua.
CREATE TABLE tmp_whenever (id NUMBER PRIMARY KEY);
INSERT INTO tmp_whenever VALUES (1);
INSERT INTO tmp_whenever VALUES (1);
INSERT INTO tmp_whenever VALUES (2);

-- Esperado: o segundo INSERT dá ORA-00001; o terceiro roda; 2 linhas na tabela
SELECT COUNT(*) FROM tmp_whenever;

ROLLBACK;

-- 2. Com WHENEVER SQLERROR EXIT, o script pararia no primeiro erro.
--    Para ver, crie um arquivo tmp_para.sql com:
--
--      WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
--      INSERT INTO tmp_whenever VALUES (10);
--      INSERT INTO tmp_whenever VALUES (10);
--      INSERT INTO tmp_whenever VALUES (20);
--
--    e rode pelo shell:  sqlplus -s estudo@//localhost:1521/FREEPDB1 @tmp_para.sql
--    Depois:             echo $?     (Linux)   |   echo %ERRORLEVEL%   (Windows)
--
--    Esperado: o SQL*Plus encerra no segundo INSERT; código de saída 1 (ORA-00001,
--              SQLCODE 1); o primeiro INSERT foi desfeito pelo ROLLBACK; o terceiro
--              nunca rodou. Sem a palavra ROLLBACK, o EXIT confirmaria o primeiro.

-- 3. CONTINUE com ROLLBACK: segue, mas desfaz o que estava pendente a cada erro.
WHENEVER SQLERROR CONTINUE ROLLBACK

INSERT INTO tmp_whenever VALUES (30);
INSERT INTO tmp_whenever VALUES (30);
INSERT INTO tmp_whenever VALUES (40);

-- Esperado: 1 linha (o 40). O erro no segundo INSERT desfez o primeiro.
SELECT COUNT(*) FROM tmp_whenever;

ROLLBACK;
WHENEVER SQLERROR CONTINUE NONE

-- 4. Erro de compilação não dispara o WHENEVER.
WHENEVER SQLERROR CONTINUE ROLLBACK

CREATE OR REPLACE PROCEDURE tmp_proc_com_erro IS
BEGIN
    UPDATE tabela_que_nao_existe SET x = 1;
END;
/
-- Esperado: "Advertência: Procedimento criado com erros de compilação." e o script segue.
--           Com WHENEVER SQLERROR EXIT, também seguiria: não é um erro ORA para o SQL*Plus.

-- A conferência que o script de deploy precisa fazer por conta própria.
-- Esperado: TMP_PROC_COM_ERRO | PROCEDURE
SELECT object_name, object_type FROM user_objects WHERE status = 'INVALID' AND object_name LIKE 'TMP%';

DROP PROCEDURE tmp_proc_com_erro;
WHENEVER SQLERROR CONTINUE NONE

-- 5. SET ERRORLOGGING: registro dos erros numa tabela.
SET ERRORLOGGING ON IDENTIFIER 'tmp_estudo_07'

INSERT INTO tmp_whenever VALUES (50);
INSERT INTO tmp_whenever VALUES (50);
SELECT * FROM tabela_inexistente;
UPDATE tmp_whenever SET id = 'abc';

SET ERRORLOGGING OFF

-- Esperado: 3 linhas: ORA-00001, ORA-00942 e ORA-01722, com o comando de cada uma
COLUMN message   FORMAT A60 TRUNCATED
COLUMN statement FORMAT A50 TRUNCATED
SELECT TO_CHAR(timestamp, 'HH24:MI:SS') AS hora, message, statement
  FROM sperrorlog
 WHERE identifier = 'tmp_estudo_07'
 ORDER BY timestamp;

ROLLBACK;

-- Limpeza: a tabela SPERRORLOG foi criada pelo SQL*Plus no seu schema.
DELETE FROM sperrorlog WHERE identifier = 'tmp_estudo_07';
COMMIT;
-- Se não houver outras linhas e você não for usar de novo:
--   DROP TABLE sperrorlog PURGE;

DROP TABLE tmp_whenever PURGE;
