-- =============================================================================
-- Tópico : REGEXP_LIKE
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Alternativa: nomes que terminam com Ltda, ME ou SA.
-- Esperado: 7 (1, 2, 3, 6, 8, 10, 11: exatamente as pessoas jurídicas)
SELECT id_cliente, nome, tipo_pessoa
  FROM clientes
 WHERE REGEXP_LIKE(nome, ' (Ltda|ME|SA)$')
 ORDER BY id_cliente;

-- 2. Ignorando maiúsculas com o parâmetro 'i'.
-- Esperado: 0 | 1
SELECT (SELECT COUNT(*) FROM clientes WHERE REGEXP_LIKE(nome, '^papel'))      AS sensivel,
       (SELECT COUNT(*) FROM clientes WHERE REGEXP_LIKE(nome, '^papel', 'i')) AS com_i
  FROM dual;

-- 3. Validação de formato: documento com 11 ou 14 dígitos, nada mais.
-- Esperado: 0 inválidos
SELECT id_cliente, documento
  FROM clientes
 WHERE NOT REGEXP_LIKE(documento, '^([0-9]{11}|[0-9]{14})$');

-- 4. Âncoras importam: sem ^ e $, 14 dígitos também casam com {11}.
-- Esperado: 12 | 5
SELECT (SELECT COUNT(*) FROM clientes WHERE REGEXP_LIKE(documento, '[0-9]{11}'))   AS sem_ancora,
       (SELECT COUNT(*) FROM clientes WHERE REGEXP_LIKE(documento, '^[0-9]{11}$')) AS com_ancora
  FROM dual;

-- 5. Coerência entre tipo de pessoa e tamanho do documento.
-- Esperado: nenhuma linha
SELECT id_cliente, tipo_pessoa, documento
  FROM clientes
 WHERE (tipo_pessoa = 'F' AND NOT REGEXP_LIKE(documento, '^[0-9]{11}$'))
    OR (tipo_pessoa = 'J' AND NOT REGEXP_LIKE(documento, '^[0-9]{14}$'));

-- 6. E-mail com estrutura mínima: algo@algo.algo, sem espaço.
--    Lista de teste com casos válidos e inválidos.
WITH emails AS (
    SELECT 'ana.ribeiro@empresa.example' AS email FROM dual UNION ALL
    SELECT 'sem-arroba.example'                  FROM dual UNION ALL
    SELECT 'com espaco@empresa.example'          FROM dual UNION ALL
    SELECT 'ponto@semdominio'                    FROM dual UNION ALL
    SELECT 'ok@sub.dominio.example'              FROM dual
)
SELECT email,
       CASE WHEN REGEXP_LIKE(email, '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
            THEN 'valido' ELSE 'invalido' END AS situacao
  FROM emails;
-- válidos: o 1o e o 5o

-- 7. Auditoria dos e-mails cadastrados com o mesmo padrão.
-- Esperado: nenhuma linha (os nulos ficam de fora: REGEXP_LIKE de NULL é UNKNOWN)
SELECT id_cliente, email
  FROM clientes
 WHERE email IS NOT NULL
   AND NOT REGEXP_LIKE(email, '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

-- 8. REGEXP_LIKE em CHECK: a regra passa a ser garantida pelo banco.
ALTER TABLE clientes ADD CONSTRAINT tmp_ck_clientes_uf
    CHECK (REGEXP_LIKE(uf, '^[A-Z]{2}$'));

-- Esperado: ORA-02290 (restrição de verificação violada)
UPDATE clientes SET uf = 'sp' WHERE id_cliente = 1;

ALTER TABLE clientes DROP CONSTRAINT tmp_ck_clientes_uf;
