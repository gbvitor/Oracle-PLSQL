-- =============================================================================
-- Caso   : Comparar duas tabelas — MINUS nos dois sentidos, UNION ALL com
--          GROUP BY, FULL OUTER JOIN com diferença por coluna, impressão digital
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
--
-- A = CLIENTES (original). B = TMP_CLIENTES_B (cópia alterada).
-- =============================================================================

CREATE TABLE tmp_clientes_b AS
SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM clientes;

UPDATE tmp_clientes_b SET limite_credito = 55000                     WHERE id_cliente = 1;
UPDATE tmp_clientes_b SET email = 'compras@modelo.example'           WHERE id_cliente = 3;
UPDATE tmp_clientes_b SET email = NULL                               WHERE id_cliente = 5;
UPDATE tmp_clientes_b SET limite_credito = 1000                      WHERE id_cliente = 7;
UPDATE tmp_clientes_b SET cidade = 'Santos'                          WHERE id_cliente = 9;
UPDATE tmp_clientes_b SET cidade = cidade                            WHERE id_cliente = 4;
DELETE FROM tmp_clientes_b                                           WHERE id_cliente = 12;
INSERT INTO tmp_clientes_b VALUES (13, 'Cliente Novo Ltda', NULL, 'Palmas', 'TO', 15000);
COMMIT;

-- 1. Contagem igual, conteúdo diferente.
-- Esperado: 12 | 12
SELECT (SELECT COUNT(*) FROM clientes) AS a, (SELECT COUNT(*) FROM tmp_clientes_b) AS b FROM dual;

-- 2. MINUS nos dois sentidos.
-- Esperado: 1, 3, 5, 7, 9, 12 (versão de A)
SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM clientes
MINUS
SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM tmp_clientes_b
ORDER BY 1;

-- Esperado: 1, 3, 5, 7, 9, 13 (versão de B)
SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM tmp_clientes_b
MINUS
SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM clientes
ORDER BY 1;

-- 3. Uma consulta só: UNION ALL e GROUP BY. Cada versão diferente aparece uma vez,
--    com a marca de onde veio.
SELECT id_cliente, nome, email, cidade, uf, limite_credito,
       CASE WHEN COUNT(em_a) > 0 THEN 'A' ELSE 'B' END AS origem
  FROM (SELECT c.id_cliente, c.nome, c.email, c.cidade, c.uf, c.limite_credito,
               1 AS em_a, TO_NUMBER(NULL) AS em_b
          FROM clientes c
        UNION ALL
        SELECT b.id_cliente, b.nome, b.email, b.cidade, b.uf, b.limite_credito,
               NULL, 1
          FROM tmp_clientes_b b)
 GROUP BY id_cliente, nome, email, cidade, uf, limite_credito
HAVING COUNT(em_a) <> COUNT(em_b)
 ORDER BY id_cliente, origem;
-- Esperado: 12 linhas — 1 A, 1 B, 3 A, 3 B, 5 A, 5 B, 7 A, 7 B, 9 A, 9 B, 12 A, 13 B

-- 4. A comparação ingênua perde as trocas que envolvem NULL.
SELECT a.id_cliente
  FROM clientes a
  JOIN tmp_clientes_b b ON b.id_cliente = a.id_cliente
 WHERE a.nome <> b.nome
    OR a.email <> b.email
    OR a.cidade <> b.cidade
    OR a.uf <> b.uf
    OR a.limite_credito <> b.limite_credito
 ORDER BY 1;
-- Esperado: 1, 9   (faltam 3, 5 e 7)

-- 5. O relatório: FULL OUTER JOIN pela chave e diferença por coluna.
SELECT NVL(a.id_cliente, b.id_cliente) AS id_cliente,
       CASE
           WHEN b.id_cliente IS NULL THEN 'SÓ EM A'
           WHEN a.id_cliente IS NULL THEN 'SÓ EM B'
           ELSE 'ALTERADO'
       END AS situacao,
       CASE WHEN a.id_cliente IS NOT NULL AND b.id_cliente IS NOT NULL THEN
       RTRIM(
             CASE WHEN DECODE(a.nome, b.nome, 0, 1) = 1
                  THEN 'nome: ' || NVL(a.nome, '(nulo)') || ' -> ' || NVL(b.nome, '(nulo)') || '; ' END
          || CASE WHEN DECODE(a.email, b.email, 0, 1) = 1
                  THEN 'email: ' || NVL(a.email, '(nulo)') || ' -> ' || NVL(b.email, '(nulo)') || '; ' END
          || CASE WHEN DECODE(a.cidade, b.cidade, 0, 1) = 1
                  THEN 'cidade: ' || NVL(a.cidade, '(nulo)') || ' -> ' || NVL(b.cidade, '(nulo)') || '; ' END
          || CASE WHEN DECODE(a.uf, b.uf, 0, 1) = 1
                  THEN 'uf: ' || NVL(a.uf, '(nulo)') || ' -> ' || NVL(b.uf, '(nulo)') || '; ' END
          || CASE WHEN DECODE(a.limite_credito, b.limite_credito, 0, 1) = 1
                  THEN 'limite_credito: ' || NVL(TO_CHAR(a.limite_credito), '(nulo)')
                       || ' -> ' || NVL(TO_CHAR(b.limite_credito), '(nulo)') || '; ' END
       , '; ')
       END AS diferencas
  FROM (SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM clientes) a
  FULL OUTER JOIN tmp_clientes_b b ON b.id_cliente = a.id_cliente
 WHERE a.id_cliente IS NULL
    OR b.id_cliente IS NULL
    OR DECODE(a.nome, b.nome, 0, 1)
     + DECODE(a.email, b.email, 0, 1)
     + DECODE(a.cidade, b.cidade, 0, 1)
     + DECODE(a.uf, b.uf, 0, 1)
     + DECODE(a.limite_credito, b.limite_credito, 0, 1) > 0
 ORDER BY 1;
-- Esperado: 7 linhas
--   1  ALTERADO  limite_credito: 50000 -> 55000
--   3  ALTERADO  email: (nulo) -> compras@modelo.example
--   5  ALTERADO  email: patricia.moura@email.example -> (nulo)
--   7  ALTERADO  limite_credito: (nulo) -> 1000
--   9  ALTERADO  cidade: Sao Paulo -> Santos
--   12 SÓ EM A   (nulo)
--   13 SÓ EM B   (nulo)
-- O cliente 4, "atualizado" com o mesmo valor, não aparece.
-- Sem o CASE externo, as linhas SÓ EM A e SÓ EM B listariam todas as colunas contra NULL.

-- 6. Impressão digital: conferência rápida sem listar.
--    O separador '|' evita que 'ab'||'c' e 'a'||'bc' deem o mesmo texto.
SELECT 'A' AS lado, COUNT(*) AS linhas,
       SUM(ORA_HASH(id_cliente || '|' || nome || '|' || email || '|' || cidade || '|'
                    || uf || '|' || limite_credito)) AS impressao
  FROM clientes
UNION ALL
SELECT 'B', COUNT(*),
       SUM(ORA_HASH(id_cliente || '|' || nome || '|' || email || '|' || cidade || '|'
                    || uf || '|' || limite_credito))
  FROM tmp_clientes_b;
-- Esperado: mesmas 12 linhas, impressões diferentes
--           (o valor do hash não é reproduzido aqui: depende da implementação)

-- Depois de igualar B a A, as impressões coincidem.
DELETE FROM tmp_clientes_b;
INSERT INTO tmp_clientes_b SELECT id_cliente, nome, email, cidade, uf, limite_credito FROM clientes;

-- Esperado: as duas linhas com o mesmo valor
SELECT 'A' AS lado, SUM(ORA_HASH(id_cliente || '|' || nome || '|' || email || '|' || cidade
                                  || '|' || uf || '|' || limite_credito)) AS impressao
  FROM clientes
UNION ALL
SELECT 'B', SUM(ORA_HASH(id_cliente || '|' || nome || '|' || email || '|' || cidade
                         || '|' || uf || '|' || limite_credito))
  FROM tmp_clientes_b;

ROLLBACK;

DROP TABLE tmp_clientes_b PURGE;
