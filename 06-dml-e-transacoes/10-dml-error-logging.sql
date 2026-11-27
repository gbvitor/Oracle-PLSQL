-- =============================================================================
-- Tópico : DML error logging (LOG ERRORS)
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

-- Destino: cópia vazia de clientes, com as mesmas constraints relevantes.
CREATE TABLE tmp_clientes (
    id_cliente  NUMBER(6)     PRIMARY KEY,
    nome        VARCHAR2(100) NOT NULL,
    tipo_pessoa CHAR(1)       NOT NULL CHECK (tipo_pessoa IN ('F', 'J')),
    documento   VARCHAR2(14)  NOT NULL UNIQUE,
    uf          CHAR(2)       NOT NULL
);

-- Arquivo de carga com 6 linhas, 3 delas inválidas.
CREATE TABLE tmp_carga (id_cliente NUMBER, nome VARCHAR2(200), tipo_pessoa VARCHAR2(5),
                        documento VARCHAR2(30), uf VARCHAR2(5));
INSERT INTO tmp_carga VALUES (1, 'Cliente valido 1',  'F', '30000000001',     'SP');
INSERT INTO tmp_carga VALUES (2, 'Cliente valido 2',  'J', '30000000000102',  'MG');
INSERT INTO tmp_carga VALUES (3, NULL,                'F', '30000000003',     'GO');
INSERT INTO tmp_carga VALUES (4, 'Tipo invalido',     'X', '30000000004',     'TO');
INSERT INTO tmp_carga VALUES (5, 'UF longa',          'F', '30000000005',     'TOC');
INSERT INTO tmp_carga VALUES (6, 'Cliente valido 3',  'F', '30000000006',     'PA');
COMMIT;

-- 1. Sem LOG ERRORS: a primeira linha inválida derruba o comando inteiro.
-- Esperado: ORA-01400 (não é possível inserir NULL); nenhuma linha inserida
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, uf)
SELECT id_cliente, nome, tipo_pessoa, documento, uf FROM tmp_carga;

-- Esperado: 0
SELECT COUNT(*) FROM tmp_clientes;

-- 2. Criar a tabela de erros: ERR$_TMP_CLIENTES.
BEGIN
    DBMS_ERRLOG.CREATE_ERROR_LOG(dml_table_name => 'TMP_CLIENTES');
END;
/

-- 3. Com LOG ERRORS: as válidas entram, as inválidas vão para a tabela de erros.
-- Esperado: 3 linhas inseridas
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, uf)
SELECT id_cliente, nome, tipo_pessoa, documento, uf FROM tmp_carga
LOG ERRORS INTO err$_tmp_clientes ('carga 1') REJECT LIMIT UNLIMITED;

-- Esperado: 1, 2, 6
SELECT id_cliente, nome FROM tmp_clientes ORDER BY id_cliente;

-- Esperado: 3 erros
--   3 -> ORA-01400 (nome nulo)
--   4 -> ORA-02290 (CHECK de tipo_pessoa)
--   5 -> ORA-12899 (uf com 3 caracteres)
SELECT id_cliente, ora_err_number$ AS erro, ora_err_optyp$ AS operacao, ora_err_tag$ AS etiqueta,
       SUBSTR(ora_err_mesg$, 1, 80) AS mensagem
  FROM err$_tmp_clientes
 ORDER BY TO_NUMBER(id_cliente);

COMMIT;

-- 4. REJECT LIMIT: tolerar no máximo 1 erro.
TRUNCATE TABLE tmp_clientes;

--    Em ordem decrescente: 6 (válida), 5 (1o erro, tolerado), 4 (2o erro).
-- Esperado: o comando falha com o erro da linha que passou do limite
--           (ORA-02290, linha 4) e é desfeito: nenhuma linha inserida
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, uf)
SELECT id_cliente, nome, tipo_pessoa, documento, uf FROM tmp_carga
 ORDER BY id_cliente DESC
LOG ERRORS INTO err$_tmp_clientes ('carga 2') REJECT LIMIT 1;

-- Esperado: 0
SELECT COUNT(*) FROM tmp_clientes;

-- 5. ROLLBACK não apaga o registro de erros.
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, uf)
SELECT id_cliente, nome, tipo_pessoa, documento, uf FROM tmp_carga
LOG ERRORS INTO err$_tmp_clientes ('carga 3') REJECT LIMIT UNLIMITED;

ROLLBACK;

-- Esperado: 0 clientes | 3 erros com a etiqueta 'carga 3'
SELECT (SELECT COUNT(*) FROM tmp_clientes)                                     AS clientes,
       (SELECT COUNT(*) FROM err$_tmp_clientes WHERE ora_err_tag$ = 'carga 3') AS erros_carga_3
  FROM dual;

-- 6. Chave única em INSERT convencional também é registrada.
--    Primeiro, as 3 válidas; depois, a mesma carga com outros ids (mesmos documentos).
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, uf)
SELECT id_cliente, nome, tipo_pessoa, documento, uf FROM tmp_carga
LOG ERRORS INTO err$_tmp_clientes ('carga 4') REJECT LIMIT UNLIMITED;
COMMIT;

-- Esperado: 0 linhas inseridas
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, uf)
SELECT id_cliente + 100, nome, tipo_pessoa, documento, uf FROM tmp_carga
LOG ERRORS INTO err$_tmp_clientes ('carga 5') REJECT LIMIT UNLIMITED;

-- Esperado na 'carga 5': 3 x ORA-00001 (documento repetido), 1 x 1400,
--                        1 x 2290, 1 x 12899
SELECT ora_err_number$ AS erro, COUNT(*) AS linhas
  FROM err$_tmp_clientes
 WHERE ora_err_tag$ = 'carga 5'
 GROUP BY ora_err_number$
 ORDER BY 1;

-- Resumo por execução.
SELECT ora_err_tag$ AS etiqueta, COUNT(*) AS erros
  FROM err$_tmp_clientes
 GROUP BY ora_err_tag$
 ORDER BY 1;

COMMIT;

-- Limpeza
DROP TABLE err$_tmp_clientes PURGE;
DROP TABLE tmp_carga PURGE;
DROP TABLE tmp_clientes PURGE;
