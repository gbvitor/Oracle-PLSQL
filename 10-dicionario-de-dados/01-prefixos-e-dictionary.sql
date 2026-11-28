-- =============================================================================
-- Tópico : Prefixos USER_, ALL_, DBA_ e CDB_; DICTIONARY e DICT_COLUMNS
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado (os valores
--          esperados contam só os objetos do schema de exemplo)
-- =============================================================================

-- 1. As três visões da mesma família.
-- Esperado: 7 (as tabelas do schema de exemplo)
SELECT COUNT(*) AS minhas_tabelas FROM user_tables;

-- Esperado: 7 ou mais (inclui tabelas de outros schemas às quais você tem acesso)
SELECT COUNT(*) AS tabelas_acessiveis FROM all_tables;

-- Esperado: as 7 tabelas; a coluna OWNER existe em ALL_ e não em USER_
SELECT owner, table_name FROM all_tables WHERE owner = USER ORDER BY table_name;

-- Esperado: funciona com SELECT_CATALOG_ROLE (concedida em 00-ambiente);
--           sem ela, ORA-00942. No FreeSQL, depende das permissões da conta.
SELECT COUNT(*) AS tabelas_no_banco FROM dba_tables;

-- 2. Quem sou eu e onde estou.
-- Esperado: ESTUDO | ESTUDO | FREEPDB1 (no container Free) | nome do serviço
SELECT USER                                  AS usuario,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS schema_atual,
       SYS_CONTEXT('USERENV', 'CON_NAME')    AS container,
       SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS servico
  FROM dual;

-- 3. DICTIONARY: achar a visão certa sem decorar.
-- Esperado: USER_CONSTRAINTS, USER_CONS_COLUMNS, USER_CONS_OBJ_COLUMNS e outras
SELECT table_name, comments
  FROM dictionary
 WHERE table_name LIKE 'USER%CONS%'
 ORDER BY table_name;

-- Tudo o que fala de "trigger" no comentário.
SELECT table_name, comments
  FROM dictionary
 WHERE table_name LIKE 'USER%'
   AND UPPER(comments) LIKE '%TRIGGER%'
 ORDER BY table_name;

-- Quantas visões existem por prefixo.
-- Esperado: centenas de USER_, ALL_ e DBA_; V$ e GV$ também aparecem
SELECT CASE
           WHEN table_name LIKE 'USER\_%' ESCAPE '\' THEN 'USER_'
           WHEN table_name LIKE 'ALL\_%'  ESCAPE '\' THEN 'ALL_'
           WHEN table_name LIKE 'DBA\_%'  ESCAPE '\' THEN 'DBA_'
           WHEN table_name LIKE 'CDB\_%'  ESCAPE '\' THEN 'CDB_'
           WHEN table_name LIKE 'V$%'                THEN 'V$'
           WHEN table_name LIKE 'GV$%'               THEN 'GV$'
           ELSE 'outras'
       END AS prefixo,
       COUNT(*) AS visoes
  FROM dictionary
 GROUP BY CASE
              WHEN table_name LIKE 'USER\_%' ESCAPE '\' THEN 'USER_'
              WHEN table_name LIKE 'ALL\_%'  ESCAPE '\' THEN 'ALL_'
              WHEN table_name LIKE 'DBA\_%'  ESCAPE '\' THEN 'DBA_'
              WHEN table_name LIKE 'CDB\_%'  ESCAPE '\' THEN 'CDB_'
              WHEN table_name LIKE 'V$%'                THEN 'V$'
              WHEN table_name LIKE 'GV$%'               THEN 'GV$'
              ELSE 'outras'
          END
 ORDER BY visoes DESC;

-- 4. DICT_COLUMNS: o que cada coluna de uma visão significa.
SELECT column_name, comments
  FROM dict_columns
 WHERE table_name = 'USER_TAB_COLUMNS'
 ORDER BY column_name;

-- 5. Nomes em maiúsculas.
-- Esperado: 0 (o dicionário guarda CLIENTES)
SELECT COUNT(*) FROM user_tables WHERE table_name = 'clientes';

-- Esperado: 1
SELECT COUNT(*) FROM user_tables WHERE table_name = 'CLIENTES';

-- Objeto criado com aspas fica com o nome exato.
CREATE TABLE "tmp_Minusculas" (id NUMBER);

-- Esperado: tmp_Minusculas (não TMP_MINUSCULAS)
SELECT table_name FROM user_tables WHERE UPPER(table_name) = 'TMP_MINUSCULAS';

-- Esperado: ORA-00942: sem aspas, o Oracle procura TMP_MINUSCULAS
SELECT * FROM tmp_minusculas;

DROP TABLE "tmp_Minusculas" PURGE;

-- 6. Coluna LONG não aceita funções de texto.
-- Esperado: ORA-00932 (tipos de dados inconsistentes: ... LONG)
SELECT table_name, column_name
  FROM user_tab_columns
 WHERE data_default LIKE '%SYSDATE%';

-- Contorno em PL/SQL: o LONG é lido para VARCHAR2.
SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
    FOR r IN (SELECT table_name, column_name, data_default
                FROM user_tab_columns
               ORDER BY table_name, column_name)
    LOOP
        IF UPPER(r.data_default) LIKE '%SYSDATE%' THEN
            DBMS_OUTPUT.PUT_LINE(r.table_name || '.' || r.column_name || ' = ' || TRIM(r.data_default));
        END IF;
    END LOOP;
END;
/
-- Esperado: CLIENTES.DATA_CADASTRO = SYSDATE
