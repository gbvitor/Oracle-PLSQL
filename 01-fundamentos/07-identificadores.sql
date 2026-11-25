-- =============================================================================
-- Tópico : Identificadores — maiúsculas, aspas e nomes gerados
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : usuário com CREATE TABLE
-- Cria tabelas tmp_ e remove no fim. Erros nos passos 2 e 4 são intencionais.
-- =============================================================================

-- 1. Sem aspas, o nome vai para o dicionário em maiúsculas.
CREATE TABLE tmp_sem_aspas (codigo NUMBER, descricao VARCHAR2(30));

-- Esperado: TMP_SEM_ASPAS
SELECT table_name FROM user_tables WHERE table_name LIKE 'TMP%';

-- funciona
SELECT COUNT(*) FROM TMP_SEM_ASPAS;
-- funciona
SELECT COUNT(*) FROM Tmp_Sem_Aspas;

-- 2. Com aspas, a grafia exata passa a ser obrigatória.
CREATE TABLE "tmp_com_aspas" ("Codigo" NUMBER, "data" DATE);

-- Esperado: tmp_com_aspas
SELECT table_name FROM user_tables WHERE table_name LIKE 'tmp%';

-- Esperado: ORA-00942 (procura TMP_COM_ASPAS)
SELECT COUNT(*) FROM tmp_com_aspas;
-- funciona
SELECT COUNT(*) FROM "tmp_com_aspas";

-- Esperado: ORA-00904 (procura CODIGO)
SELECT Codigo FROM "tmp_com_aspas";
-- funciona
SELECT "Codigo", "data" FROM "tmp_com_aspas";

-- 3. Palavras reservadas: a coluna "data" só existe por causa das aspas.
--    DATE é reservada; DATA não é. Conferindo:
SELECT keyword, reserved
  FROM v$reserved_words
 WHERE keyword IN ('DATE', 'DATA', 'LEVEL', 'COMMENT', 'NOME')
 ORDER BY keyword;
-- NOME não aparece: não é palavra-chave do Oracle.

-- 4. Limite de 128 bytes.
-- ok
CREATE TABLE tmp_nome_dentro_do_limite_de_cento_e_vinte_e_oito_bytes (x NUMBER);

-- Esperado: ORA-00972 (identificador longo demais; o nome tem 133 caracteres)
CREATE TABLE tmp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx (x NUMBER);

-- 5. Constraint sem nome recebe nome gerado pelo sistema.
ALTER TABLE tmp_sem_aspas ADD PRIMARY KEY (codigo);

SELECT constraint_name, constraint_type, generated
  FROM user_constraints
 WHERE table_name = 'TMP_SEM_ASPAS';
-- SYS_C00nnnnn | P | GENERATED NAME

-- 6. Espaço de nomes compartilhado: sequence com o nome de uma tabela existente.
-- Esperado: ORA-00955 (nome já usado por objeto existente)
CREATE SEQUENCE tmp_sem_aspas;

-- Limpeza
DROP TABLE tmp_sem_aspas PURGE;
DROP TABLE "tmp_com_aspas" PURGE;
DROP TABLE tmp_nome_dentro_do_limite_de_cento_e_vinte_e_oito_bytes PURGE;
