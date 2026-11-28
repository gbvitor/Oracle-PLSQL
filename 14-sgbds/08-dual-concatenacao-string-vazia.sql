-- =============================================================================
-- Tópico : O lado Oracle das diferenças de comportamento (para comparar com os
--          valores dos outros SGBDs no .md)
-- Seção  : 14-sgbds
-- Versão : 19c
-- Requer : nada além de uma conexão
-- =============================================================================

-- 1. String vazia é NULL.
-- Esperado: NULL | é nulo
SELECT LENGTH('') AS tamanho,
       CASE WHEN '' IS NULL THEN 'é nulo' ELSE 'não é nulo' END AS teste
  FROM dual;
-- PostgreSQL / SQL Server / MySQL: 0 | não é nulo

-- 2. NULL some na concatenação.
-- Esperado: a | a
SELECT 'a' || NULL AS com_operador, CONCAT('a', NULL) AS com_concat FROM dual;
-- PostgreSQL: NULL | a     SQL Server ('a' + NULL / CONCAT): NULL | a     MySQL (CONCAT): NULL

-- 3. Divisão de inteiros.
-- Esperado: 3.5
SELECT 7 / 2 AS divisao FROM dual;
-- PostgreSQL e SQL Server: 3     MySQL: 3.5000

-- 4. Maiúsculas importam na comparação de texto.
-- Esperado: diferentes
SELECT CASE WHEN 'abc' = 'ABC' THEN 'iguais' ELSE 'diferentes' END AS comparacao FROM dual;
-- SQL Server e MySQL (collation padrão): iguais     PostgreSQL: diferentes

-- 5. GREATEST com NULL.
-- Esperado: NULL
SELECT GREATEST(1, NULL, 3) AS maior FROM dual;
-- PostgreSQL e SQL Server 2022+: 3 (ignoram NULL)     MySQL: NULL

-- 6. NULL na ordenação crescente vem por último.
-- Esperado: 1 | 2 | (nulo)
SELECT valor
  FROM (SELECT 2 AS valor FROM dual UNION ALL SELECT NULL FROM dual UNION ALL SELECT 1 FROM dual)
 ORDER BY valor;
-- SQL Server e MySQL: NULL primeiro     PostgreSQL: por último, como o Oracle

-- 7. Nomes sem aspas são guardados em maiúsculas.
CREATE TABLE tmp_MinhaTabela (id NUMBER);
-- Esperado: TMP_MINHATABELA
SELECT table_name FROM user_tables WHERE UPPER(table_name) = 'TMP_MINHATABELA';
DROP TABLE tmp_minhatabela PURGE;
-- PostgreSQL: tmp_minhatabela (minúsculas)     SQL Server e MySQL: como foi escrito

-- 8. DDL confirma a transação.
CREATE TABLE tmp_ddl_tx (id NUMBER);
INSERT INTO tmp_ddl_tx VALUES (1);
CREATE TABLE tmp_ddl_tx2 (id NUMBER);
ROLLBACK;
-- Esperado: 1 (o CREATE TABLE confirmou o INSERT antes dele; o ROLLBACK não tem o que desfazer)
SELECT COUNT(*) FROM tmp_ddl_tx;
DROP TABLE tmp_ddl_tx  PURGE;
DROP TABLE tmp_ddl_tx2 PURGE;
-- PostgreSQL e SQL Server, dentro de BEGIN: o ROLLBACK desfaria o INSERT e as duas tabelas
