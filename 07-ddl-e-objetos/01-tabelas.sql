-- =============================================================================
-- Tópico : Tabelas — CREATE, CTAS, ALTER, DROP, lixeira, FLASHBACK TABLE
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

-- 1. CTAS copia dados e NOT NULL, mas não PK, FK, CHECK, índices nem DEFAULT.
CREATE TABLE tmp_clientes AS SELECT * FROM clientes;

-- Esperado: clientes tem P, U, C (check e not null); a cópia só os NOT NULL (C)
SELECT table_name, constraint_type, COUNT(*) AS qtd
  FROM user_constraints
 WHERE table_name IN ('CLIENTES', 'TMP_CLIENTES')
 GROUP BY table_name, constraint_type
 ORDER BY table_name, constraint_type;

-- Esperado: CLIENTES com 2 índices (PK e UK); TMP_CLIENTES sem índice
SELECT table_name, COUNT(*) AS indices
  FROM user_indexes
 WHERE table_name IN ('CLIENTES', 'TMP_CLIENTES')
 GROUP BY table_name;

-- O DEFAULT de data_cadastro também não veio.
-- Esperado: CLIENTES -> SYSDATE | TMP_CLIENTES -> nulo
SELECT table_name, column_name, data_default
  FROM user_tab_columns
 WHERE table_name IN ('CLIENTES', 'TMP_CLIENTES')
   AND column_name = 'DATA_CADASTRO';

-- Só a estrutura, sem dados.
CREATE TABLE tmp_vazia AS SELECT * FROM clientes WHERE 1 = 0;

-- Esperado: 0
SELECT COUNT(*) FROM tmp_vazia;

DROP TABLE tmp_vazia PURGE;

-- 2. ALTER TABLE: incluir, alterar, renomear, remover colunas.
ALTER TABLE tmp_clientes ADD (segmento VARCHAR2(20) DEFAULT 'varejo' NOT NULL);

-- A coluna nova já aparece preenchida em todas as linhas.
-- Esperado: 12 linhas com 'varejo'
SELECT segmento, COUNT(*) FROM tmp_clientes GROUP BY segmento;

ALTER TABLE tmp_clientes MODIFY (nome VARCHAR2(200));
ALTER TABLE tmp_clientes RENAME COLUMN segmento TO segmento_comercial;

-- Diminuir abaixo do maior valor existente: recusado.
-- Esperado: ORA-01441 (não é possível diminuir o tamanho da coluna porque algum valor é grande demais)
ALTER TABLE tmp_clientes MODIFY (nome VARCHAR2(10));

-- Tornar obrigatória uma coluna com nulos: recusado.
-- Esperado: ORA-02296 (não é possível ativar (...) - valores nulos encontrados)
ALTER TABLE tmp_clientes MODIFY (email NOT NULL);

-- SET UNUSED: a coluna some na hora; a remoção física fica para depois.
ALTER TABLE tmp_clientes SET UNUSED COLUMN limite_credito;

-- Esperado: ORA-00904 ("LIMITE_CREDITO": identificador inválido)
SELECT limite_credito FROM tmp_clientes;

ALTER TABLE tmp_clientes DROP UNUSED COLUMNS;

-- 3. Somente leitura.
ALTER TABLE tmp_clientes READ ONLY;

-- Esperado: ORA-12081 (operação de atualização não permitida na tabela)
UPDATE tmp_clientes SET nome = nome WHERE id_cliente = 1;

ALTER TABLE tmp_clientes READ WRITE;

-- 4. DROP vai para a lixeira; FLASHBACK TABLE recupera.
ALTER TABLE tmp_clientes ADD CONSTRAINT pk_tmp_clientes PRIMARY KEY (id_cliente);

DROP TABLE tmp_clientes;

-- Esperado: a tabela e o índice da PK, com nomes BIN$...
SELECT object_name, original_name, type, droptime
  FROM user_recyclebin
 WHERE original_name IN ('TMP_CLIENTES', 'PK_TMP_CLIENTES');

FLASHBACK TABLE tmp_clientes TO BEFORE DROP;

-- Esperado: 12 (dados de volta)
SELECT COUNT(*) FROM tmp_clientes;

-- A constraint e o índice voltaram com nome BIN$...; renomear.
SELECT constraint_name, constraint_type
  FROM user_constraints
 WHERE table_name = 'TMP_CLIENTES' AND constraint_type = 'P';

-- 5. DROP ... PURGE não passa pela lixeira.
DROP TABLE tmp_clientes PURGE;

-- Esperado: nenhuma linha de TMP_CLIENTES na lixeira (a do passo 4 foi recuperada)
SELECT COUNT(*) FROM user_recyclebin WHERE original_name = 'TMP_CLIENTES';

-- Esperado: ORA-38305 (objeto não está na LIXEIRA)
FLASHBACK TABLE tmp_clientes TO BEFORE DROP;

-- 6. Script que pode rodar várias vezes no 19c: tratar ORA-00942 / ORA-00955.
DECLARE
    e_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_inexistente, -942);
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tmp_repetivel PURGE';
EXCEPTION
    WHEN e_inexistente THEN NULL;
END;
/

CREATE TABLE tmp_repetivel (id NUMBER);

-- [23ai+] Equivalente direto, sem PL/SQL:
--   DROP TABLE IF EXISTS tmp_repetivel PURGE
--   CREATE TABLE IF NOT EXISTS tmp_repetivel (id NUMBER)

DROP TABLE tmp_repetivel PURGE;
