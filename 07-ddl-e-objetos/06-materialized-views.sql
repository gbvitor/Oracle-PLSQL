-- =============================================================================
-- Tópico : Materialized views — refresh completo, rápido e ON COMMIT
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE MATERIALIZED VIEW e
--          CREATE TABLE (o usuário de estudo tem os dois)
-- Trabalha sobre cópias das tabelas, para não deixar MV log no schema de exemplo.
-- =============================================================================

CREATE TABLE tmp_pedidos AS SELECT * FROM pedidos;
CREATE TABLE tmp_itens   AS SELECT * FROM itens_pedido;
ALTER TABLE tmp_pedidos ADD CONSTRAINT pk_tmp_pedidos PRIMARY KEY (id_pedido);
ALTER TABLE tmp_itens   ADD CONSTRAINT pk_tmp_itens   PRIMARY KEY (id_pedido, nr_item);

-- 1. MV de vendas por mês, com refresh completo sob demanda.
CREATE MATERIALIZED VIEW tmp_mv_vendas_mes
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT TO_CHAR(p.data_pedido, 'YYYY-MM') AS mes,
       COUNT(DISTINCT p.id_pedido)       AS pedidos,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM tmp_pedidos p
  JOIN tmp_itens   i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY TO_CHAR(p.data_pedido, 'YYYY-MM');

-- Esperado: 2026-10 -> 2 pedidos, 4049.00
SELECT * FROM tmp_mv_vendas_mes WHERE mes = '2026-10';

-- 2. Mudança na origem: a MV fica desatualizada.
INSERT INTO tmp_pedidos (id_pedido, id_cliente, id_vendedor, data_pedido, status)
VALUES (1025, 2, 104, DATE '2026-10-31', 'ABERTO');
INSERT INTO tmp_itens VALUES (1025, 1, 3, 1, 899.00, 0);
COMMIT;

-- Esperado: ainda 2 pedidos, 4049.00 (resultado gravado, não recalculado)
SELECT * FROM tmp_mv_vendas_mes WHERE mes = '2026-10';

-- Esperado: STALE
SELECT mview_name, staleness, last_refresh_type, last_refresh_date
  FROM user_mviews
 WHERE mview_name = 'TMP_MV_VENDAS_MES';

-- 3. Refresh completo.
BEGIN
    DBMS_MVIEW.REFRESH('TMP_MV_VENDAS_MES', method => 'C');
END;
/

-- Esperado: 3 pedidos, 4948.00 | FRESH
SELECT * FROM tmp_mv_vendas_mes WHERE mes = '2026-10';

SELECT mview_name, staleness, last_refresh_type FROM user_mviews WHERE mview_name = 'TMP_MV_VENDAS_MES';

-- 4. Refresh rápido ON COMMIT: precisa de MV log e de COUNT junto dos SUMs.
CREATE MATERIALIZED VIEW LOG ON tmp_itens
  WITH ROWID, SEQUENCE (id_pedido, quantidade)
  INCLUDING NEW VALUES;

CREATE MATERIALIZED VIEW tmp_mv_qtd_pedido
  BUILD IMMEDIATE
  REFRESH FAST ON COMMIT
AS
SELECT id_pedido,
       COUNT(*)          AS itens,
       SUM(quantidade)   AS qtd_total,
       COUNT(quantidade) AS qtd_contagem
  FROM tmp_itens
 GROUP BY id_pedido;

-- Esperado: 1001 -> 3 itens, 35 unidades
SELECT * FROM tmp_mv_qtd_pedido WHERE id_pedido = 1001;

-- Alterar a origem e confirmar: a MV é atualizada no COMMIT.
INSERT INTO tmp_itens VALUES (1001, 4, 6, 5, 49.90, 0);
COMMIT;

-- Esperado: 1001 -> 4 itens, 40 unidades
SELECT * FROM tmp_mv_qtd_pedido WHERE id_pedido = 1001;

-- 5. MV com SUM sem o COUNT correspondente não aceita FAST.
-- Esperado: erro de criação por falta de requisito do refresh rápido
-- (normalmente ORA-12054; DBMS_MVIEW.EXPLAIN_MVIEW mostra o motivo exato)
CREATE MATERIALIZED VIEW tmp_mv_sem_count
  REFRESH FAST ON COMMIT
AS
SELECT id_pedido, SUM(quantidade) AS qtd_total
  FROM tmp_itens
 GROUP BY id_pedido;

-- 6. A MV é um objeto com segmento próprio (uma tabela por trás).
SELECT object_name, object_type
  FROM user_objects
 WHERE object_name IN ('TMP_MV_VENDAS_MES', 'TMP_MV_QTD_PEDIDO', 'MLOG$_TMP_ITENS')
 ORDER BY object_name, object_type;
-- Esperado: MATERIALIZED VIEW e TABLE para cada MV; TABLE para o log MLOG$_TMP_ITENS

-- Limpeza
DROP MATERIALIZED VIEW tmp_mv_qtd_pedido;
DROP MATERIALIZED VIEW tmp_mv_vendas_mes;
DROP MATERIALIZED VIEW LOG ON tmp_itens;
DROP TABLE tmp_itens PURGE;
DROP TABLE tmp_pedidos PURGE;
