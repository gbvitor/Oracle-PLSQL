-- =============================================================================
-- Tópico : INSERT ALL e INSERT FIRST
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

-- Destinos: mesma estrutura, vazios.
CREATE TABLE tmp_grandes   (id_pedido NUMBER, status VARCHAR2(12), valor NUMBER(12,2));
CREATE TABLE tmp_entregues (id_pedido NUMBER, status VARCHAR2(12), valor NUMBER(12,2));
CREATE TABLE tmp_outros    (id_pedido NUMBER, status VARCHAR2(12), valor NUMBER(12,2));

-- Origem: valor de cada pedido (inclusive o cancelado).
--   Pedidos acima de 10 mil: 1002, 1008, 1014 (ENTREGUE) e 1020 (FATURADO).

-- 1. INSERT ALL condicional: a linha vai para todos os destinos que se aplicam.
-- Esperado: 27 linhas inseridas (grandes 4 | entregues 17 | outros 6)
INSERT ALL
    WHEN valor > 10000        THEN INTO tmp_grandes   VALUES (id_pedido, status, valor)
    WHEN status = 'ENTREGUE'  THEN INTO tmp_entregues VALUES (id_pedido, status, valor)
    ELSE                           INTO tmp_outros    VALUES (id_pedido, status, valor)
SELECT p.id_pedido, p.status,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido, p.status;

SELECT (SELECT COUNT(*) FROM tmp_grandes)   AS grandes,
       (SELECT COUNT(*) FROM tmp_entregues) AS entregues,
       (SELECT COUNT(*) FROM tmp_outros)    AS outros
  FROM dual;

-- Os 3 pedidos grandes e entregues estão nas duas tabelas.
-- Esperado: 1002, 1008, 1014
SELECT id_pedido FROM tmp_grandes
INTERSECT
SELECT id_pedido FROM tmp_entregues
 ORDER BY 1;

ROLLBACK;

-- 2. INSERT FIRST: cada linha vai só para o primeiro destino que se aplica.
-- Esperado: 24 linhas inseridas (grandes 4 | entregues 14 | outros 6)
INSERT FIRST
    WHEN valor > 10000        THEN INTO tmp_grandes   VALUES (id_pedido, status, valor)
    WHEN status = 'ENTREGUE'  THEN INTO tmp_entregues VALUES (id_pedido, status, valor)
    ELSE                           INTO tmp_outros    VALUES (id_pedido, status, valor)
SELECT p.id_pedido, p.status,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos      p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido, p.status;

SELECT (SELECT COUNT(*) FROM tmp_grandes)   AS grandes,
       (SELECT COUNT(*) FROM tmp_entregues) AS entregues,
       (SELECT COUNT(*) FROM tmp_outros)    AS outros
  FROM dual;

ROLLBACK;

-- 3. Colunas para linhas: uma tabela larga vira uma tabela de pares.
CREATE TABLE tmp_metas_largas (id_vendedor NUMBER, meta_t1 NUMBER, meta_t2 NUMBER, meta_t3 NUMBER, meta_t4 NUMBER);
INSERT INTO tmp_metas_largas VALUES (104, 10000, 12000, 11000, 15000);
INSERT INTO tmp_metas_largas VALUES (105,  8000,  9000,  9500, 12000);

CREATE TABLE tmp_metas (id_vendedor NUMBER, trimestre NUMBER, meta NUMBER);

-- Esperado: 8 linhas inseridas (2 vendedores x 4 trimestres)
INSERT ALL
    INTO tmp_metas VALUES (id_vendedor, 1, meta_t1)
    INTO tmp_metas VALUES (id_vendedor, 2, meta_t2)
    INTO tmp_metas VALUES (id_vendedor, 3, meta_t3)
    INTO tmp_metas VALUES (id_vendedor, 4, meta_t4)
SELECT * FROM tmp_metas_largas;

SELECT * FROM tmp_metas ORDER BY id_vendedor, trimestre;

-- 4. Várias linhas literais (alternativa ao VALUES múltiplo do 23ai).
-- Esperado: 3 linhas inseridas
INSERT ALL
    INTO tmp_metas VALUES (106, 1, 20000)
    INTO tmp_metas VALUES (106, 2, 21000)
    INTO tmp_metas VALUES (106, 3, 22000)
SELECT * FROM dual;

-- 5. NEXTVAL é avaliado uma vez por linha da origem, não por INTO.
CREATE SEQUENCE tmp_seq;
CREATE TABLE tmp_a (id NUMBER, origem NUMBER);
CREATE TABLE tmp_b (id NUMBER, origem NUMBER);

INSERT ALL
    INTO tmp_a VALUES (tmp_seq.NEXTVAL, n)
    INTO tmp_b VALUES (tmp_seq.NEXTVAL, n)
SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 3;

-- Esperado: os mesmos ids nas duas tabelas (1, 2, 3), e não 1 a 6
SELECT 'a' AS tabela, id, origem FROM tmp_a
UNION ALL
SELECT 'b', id, origem FROM tmp_b
 ORDER BY 3, 1;

-- Limpeza
DROP SEQUENCE tmp_seq;
DROP TABLE tmp_a PURGE;
DROP TABLE tmp_b PURGE;
DROP TABLE tmp_metas PURGE;
DROP TABLE tmp_metas_largas PURGE;
DROP TABLE tmp_grandes PURGE;
DROP TABLE tmp_entregues PURGE;
DROP TABLE tmp_outros PURGE;
