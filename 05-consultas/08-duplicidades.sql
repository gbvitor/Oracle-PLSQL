-- =============================================================================
-- Tópico : Encontrar e remover duplicidades
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- Trabalha numa cópia de clientes com duplicidades propositais.
-- =============================================================================

-- Preparação: cópia sem constraints, com 4 linhas repetidas.
CREATE TABLE tmp_clientes AS
SELECT id_cliente, nome, documento, email, cidade, uf, data_cadastro FROM clientes;

-- Mesmo documento do cliente 1, cadastrado de novo com outra grafia.
INSERT INTO tmp_clientes VALUES (101, 'PAPELARIA CENTRAL LTDA.', '10000000000101',
                                 'contato@papelariacentral.example', 'Sao Paulo', 'SP', DATE '2024-05-10');
-- Mesmo documento do cliente 4, duas vezes, uma delas com e-mail vazio.
INSERT INTO tmp_clientes VALUES (102, 'Marcos Antonio Silva', '20000000001',
                                 NULL, 'Goiania', 'GO', DATE '2023-01-15');
INSERT INTO tmp_clientes VALUES (103, 'Marcos A. Silva',      '20000000001',
                                 'marcos.silva@email.example', 'Goiania', 'GO', DATE '2025-09-01');
-- Documento diferente, nome quase igual ao do cliente 8.
INSERT INTO tmp_clientes VALUES (104, 'Clinica Bem-Estar Ltda', '10000000000199',
                                 NULL, 'Salvador', 'BA', DATE '2025-02-02');
COMMIT;

-- 1. Chaves repetidas (documento).
-- Esperado: 10000000000101 -> 2 | 20000000001 -> 3
SELECT documento, COUNT(*) AS vezes
  FROM tmp_clientes
 GROUP BY documento
HAVING COUNT(*) > 1
 ORDER BY documento;

-- 2. Todas as linhas dos grupos repetidos, lado a lado.
-- Esperado: 5 linhas (ids 1, 101, 4, 102, 103)
SELECT *
  FROM (SELECT t.*, COUNT(*) OVER (PARTITION BY documento) AS vezes
          FROM tmp_clientes t)
 WHERE vezes > 1
 ORDER BY documento, data_cadastro;

-- 3. Qual fica: o cadastro mais antigo de cada documento.
-- Esperado: ficam 1 e 4 (rn = 1); saem 101, 102 e 103
SELECT documento, id_cliente, nome, data_cadastro,
       ROW_NUMBER() OVER (PARTITION BY documento ORDER BY data_cadastro, id_cliente) AS rn
  FROM tmp_clientes
 WHERE documento IN ('10000000000101', '20000000001')
 ORDER BY documento, rn;

-- Outro critério: o mais completo (com e-mail) e, entre eles, o mais recente.
-- Esperado: ficam 101 e 103
SELECT documento, id_cliente, email,
       ROW_NUMBER() OVER (PARTITION BY documento
                          ORDER BY CASE WHEN email IS NOT NULL THEN 0 ELSE 1 END,
                                   data_cadastro DESC, id_cliente) AS rn
  FROM tmp_clientes
 WHERE documento IN ('10000000000101', '20000000001')
 ORDER BY documento, rn;

-- 4. Duplicidade "quase igual" pelo nome normalizado.
--    Maiúsculas, só letras e números (sem espaço nem pontuação).
-- Esperado: CLINICABEMESTARLTDA (8, 104) | MARCOSANTONIOSILVA (4, 102)
--           | PAPELARIACENTRALLTDA (1, 101)
--           O 103 ("Marcos A. Silva") não casa pelo nome: só o documento revela.
SELECT nome_normalizado, COUNT(*) AS vezes,
       LISTAGG(id_cliente, ', ') WITHIN GROUP (ORDER BY id_cliente) AS ids
  FROM (SELECT id_cliente,
               UPPER(REGEXP_REPLACE(nome, '[^[:alnum:]]')) AS nome_normalizado
          FROM tmp_clientes)
 GROUP BY nome_normalizado
HAVING COUNT(*) > 1
 ORDER BY nome_normalizado;

-- 5. Remover: guardar as linhas que vão sair, apagar, conferir.
CREATE TABLE tmp_clientes_removidos AS
SELECT *
  FROM tmp_clientes
 WHERE ROWID IN (SELECT rid
                   FROM (SELECT ROWID AS rid,
                                ROW_NUMBER() OVER (PARTITION BY documento
                                                   ORDER BY data_cadastro, id_cliente) AS rn
                           FROM tmp_clientes)
                  WHERE rn > 1);

-- Esperado: 3 linhas guardadas (101, 102, 103)
SELECT id_cliente, nome FROM tmp_clientes_removidos ORDER BY id_cliente;

-- Esperado: 3 linhas apagadas
DELETE FROM tmp_clientes
 WHERE ROWID IN (SELECT rid
                   FROM (SELECT ROWID AS rid,
                                ROW_NUMBER() OVER (PARTITION BY documento
                                                   ORDER BY data_cadastro, id_cliente) AS rn
                           FROM tmp_clientes)
                  WHERE rn > 1);

-- Esperado: nenhuma linha
SELECT documento, COUNT(*) FROM tmp_clientes GROUP BY documento HAVING COUNT(*) > 1;

COMMIT;

-- 6. Impedir que volte.
ALTER TABLE tmp_clientes ADD CONSTRAINT uk_tmp_clientes_documento UNIQUE (documento);

-- Esperado: ORA-00001 (restrição exclusiva violada)
INSERT INTO tmp_clientes VALUES (105, 'Outra Papelaria', '10000000000101', NULL, 'Recife', 'PE', SYSDATE);

-- 7. Linhas idênticas em todas as colunas: só o ROWID as distingue.
INSERT INTO tmp_clientes_removidos SELECT * FROM tmp_clientes_removidos WHERE id_cliente = 101;

-- Esperado: 2 linhas iguais, ROWIDs diferentes
SELECT ROWID, id_cliente, nome FROM tmp_clientes_removidos WHERE id_cliente = 101;

ROLLBACK;

-- Limpeza
DROP TABLE tmp_clientes PURGE;
DROP TABLE tmp_clientes_removidos PURGE;
