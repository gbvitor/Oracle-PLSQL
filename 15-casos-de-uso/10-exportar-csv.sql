-- =============================================================================
-- Caso   : Exportação para CSV — function genérica com DBMS_SQL, SPOOL do
--          resultado no SQL*Plus e gravação no servidor com UTL_FILE
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
--          Parte 4: DIRECTORY criado por DBA e EXECUTE em UTL_FILE
-- =============================================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';

-- 1. A function.
CREATE OR REPLACE FUNCTION tmp_fn_csv (
    p_sql       IN VARCHAR2,
    p_sep       IN VARCHAR2 DEFAULT ';',
    p_cabecalho IN VARCHAR2 DEFAULT 'S'
) RETURN CLOB
AUTHID CURRENT_USER
IS
    c_tam_valor CONSTANT PLS_INTEGER := 4000;
    v_cursor    INTEGER;
    v_colunas   DBMS_SQL.DESC_TAB2;
    v_qtd       INTEGER;
    v_valor     VARCHAR2(4000);
    v_linha     VARCHAR2(32767);
    v_csv       CLOB;
    v_ignorar   INTEGER;

    -- Aspas quando o campo tem separador, aspas ou quebra de linha (RFC 4180).
    FUNCTION campo (p IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF INSTR(p, p_sep) > 0 OR INSTR(p, '"') > 0
           OR INSTR(p, CHR(10)) > 0 OR INSTR(p, CHR(13)) > 0 THEN
            RETURN '"' || REPLACE(p, '"', '""') || '"';
        END IF;
        RETURN p;
    END campo;

    PROCEDURE gravar_linha IS
    BEGIN
        v_linha := v_linha || CHR(10);
        DBMS_LOB.WRITEAPPEND(v_csv, LENGTH(v_linha), v_linha);
    END gravar_linha;
BEGIN
    -- DBMS_SQL.PARSE executa DDL no ato: só consulta passa.
    IF NOT REGEXP_LIKE(p_sql, '^\s*(SELECT|WITH)\s', 'i') THEN
        RAISE_APPLICATION_ERROR(-20001, 'tmp_fn_csv aceita apenas SELECT ou WITH');
    END IF;

    DBMS_LOB.CREATETEMPORARY(v_csv, TRUE);

    v_cursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(v_cursor, p_sql, DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS2(v_cursor, v_qtd, v_colunas);

    -- Toda coluna lida como texto: número e data convertidos pelas regras NLS da sessão.
    FOR i IN 1 .. v_qtd LOOP
        DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_valor, c_tam_valor);
    END LOOP;

    IF p_cabecalho = 'S' THEN
        v_linha := NULL;
        FOR i IN 1 .. v_qtd LOOP
            v_linha := v_linha || CASE WHEN i > 1 THEN p_sep END || campo(v_colunas(i).col_name);
        END LOOP;
        gravar_linha;
    END IF;

    v_ignorar := DBMS_SQL.EXECUTE(v_cursor);

    WHILE DBMS_SQL.FETCH_ROWS(v_cursor) > 0 LOOP
        v_linha := NULL;
        FOR i IN 1 .. v_qtd LOOP
            DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_valor);
            v_linha := v_linha || CASE WHEN i > 1 THEN p_sep END || campo(v_valor);
        END LOOP;
        gravar_linha;
    END LOOP;

    DBMS_SQL.CLOSE_CURSOR(v_cursor);
    RETURN v_csv;
EXCEPTION
    WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(v_cursor) THEN
            DBMS_SQL.CLOSE_CURSOR(v_cursor);
        END IF;
        RAISE;
END tmp_fn_csv;
/

SHOW ERRORS FUNCTION tmp_fn_csv

-- Para ver o CLOB inteiro no SQL*Plus.
SET LONG 1000000
SET LONGCHUNKSIZE 32767
SET PAGESIZE 0
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TRIMOUT ON
SET FEEDBACK OFF

-- 2. Escape dos campos.
SELECT tmp_fn_csv(q'[SELECT 'Silva; Souza' AS a, 'Diz "olá"' AS b, 'linha1' || CHR(10) || 'linha2' AS c, 'simples' AS d FROM dual]')
  FROM dual;
-- Esperado:
--   A;B;C;D
--   "Silva; Souza";"Diz ""olá""";"linha1
--   linha2";simples

-- 3. Clientes: conversão implícita x formatação explícita.
SELECT tmp_fn_csv(q'[SELECT id_cliente, nome, cidade, limite_credito, data_cadastro FROM clientes WHERE id_cliente IN (1, 4, 7) ORDER BY id_cliente]')
  FROM dual;
-- Esperado (limite sem casas decimais, porque a conversão é implícita):
--   ID_CLIENTE;NOME;CIDADE;LIMITE_CREDITO;DATA_CADASTRO
--   1;Papelaria Central Ltda;Sao Paulo;50000;10/02/2021
--   4;Marcos Antonio Silva;Goiania;5000;30/03/2022
--   7;Rafael Teixeira;Curitiba;;25/01/2023

SELECT tmp_fn_csv(q'[SELECT id_cliente, nome, TO_CHAR(limite_credito, 'FM9999999990D00') AS limite, TO_CHAR(data_cadastro, 'YYYY-MM-DD') AS cadastro FROM clientes WHERE id_cliente IN (1, 4, 7) ORDER BY id_cliente]')
  FROM dual;
-- Esperado:
--   ID_CLIENTE;NOME;LIMITE;CADASTRO
--   1;Papelaria Central Ltda;50000,00;2021-02-10
--   4;Marcos Antonio Silva;5000,00;2022-03-30
--   7;Rafael Teixeira;;2023-01-25

-- Para um sistema: vírgula como separador e ponto decimal. Nenhum campo tem vírgula,
-- então nada vai entre aspas; um nome com vírgula iria.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

SELECT tmp_fn_csv(q'[SELECT id_produto, nome, preco_unitario FROM produtos WHERE id_produto IN (1, 11) ORDER BY 1]', ',')
  FROM dual;
-- Esperado:
--   ID_PRODUTO,NOME,PRECO_UNITARIO
--   1,Mouse optico USB,39.9
--   11,"Mesa de escritorio 1,20 m",649
--   (o nome do produto 11 tem vírgula e vai entre aspas)

ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';

-- A proteção contra comando que não é consulta.
-- Esperado: ORA-20001: tmp_fn_csv aceita apenas SELECT ou WITH
SELECT tmp_fn_csv('DROP TABLE clientes') FROM dual;

-- 4. Arquivo na máquina do cliente: SPOOL do resultado.
SET HEADING OFF
SPOOL clientes.csv
SELECT tmp_fn_csv(q'[SELECT id_cliente, nome, cidade, uf FROM clientes ORDER BY id_cliente]') FROM dual;
SPOOL OFF
SET HEADING ON
-- Esperado: clientes.csv no diretório de onde o SQL*Plus foi aberto, com 13 linhas
--           (cabeçalho e 12 clientes)

-- 5. Arquivo no servidor do banco: UTL_FILE. [DBA para o diretório]
--
-- Como DBA, uma vez:
--   CREATE DIRECTORY dir_export AS '/u01/app/oracle/export';
--   GRANT READ, WRITE ON DIRECTORY dir_export TO curso;
--
-- A procedure compila com EXECUTE em UTL_FILE (concedido a PUBLIC numa instalação
-- padrão, mas às vezes revogado por política de segurança: aí dá PLS-00201).
CREATE OR REPLACE PROCEDURE tmp_prc_gravar_clob (
    p_diretorio IN VARCHAR2,
    p_arquivo   IN VARCHAR2,
    p_conteudo  IN CLOB
) IS
    v_arq UTL_FILE.FILE_TYPE;
    v_tam PLS_INTEGER := DBMS_LOB.GETLENGTH(p_conteudo);
    v_pos PLS_INTEGER := 1;
    v_fim PLS_INTEGER;
BEGIN
    v_arq := UTL_FILE.FOPEN(p_diretorio, p_arquivo, 'w', 32767);
    -- Uma chamada por linha: PUT_LINE aceita até 32767 bytes.
    WHILE v_pos <= v_tam LOOP
        v_fim := DBMS_LOB.INSTR(p_conteudo, CHR(10), v_pos);
        IF v_fim = 0 THEN
            v_fim := v_tam + 1;
        END IF;
        UTL_FILE.PUT_LINE(v_arq, DBMS_LOB.SUBSTR(p_conteudo, v_fim - v_pos, v_pos));
        v_pos := v_fim + 1;
    END LOOP;
    UTL_FILE.FCLOSE(v_arq);
EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(v_arq) THEN
            UTL_FILE.FCLOSE(v_arq);
        END IF;
        RAISE;
END tmp_prc_gravar_clob;
/

SHOW ERRORS PROCEDURE tmp_prc_gravar_clob

-- Com o diretório criado, a chamada é:
--   EXEC tmp_prc_gravar_clob('DIR_EXPORT', 'clientes.csv', tmp_fn_csv('SELECT * FROM clientes'))
-- Sem o diretório ou sem o grant: ORA-29280 (caminho de diretório inválido) ou ORA-29289/ORA-29283.
-- O nome do diretório vai em maiúsculas: é o nome do objeto DIRECTORY, não o caminho.

SET PAGESIZE 14
SET LINESIZE 80
SET FEEDBACK ON

DROP PROCEDURE tmp_prc_gravar_clob;
DROP FUNCTION tmp_fn_csv;
