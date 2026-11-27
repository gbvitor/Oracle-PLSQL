-- =============================================================================
-- Tópico : Índices — B-tree, composto, função, invisível, NULL
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : usuário com CREATE TABLE
-- O schema de exemplo é pequeno demais para o otimizador preferir índices.
-- Por isso os exemplos usam uma tabela de teste com 100 mil linhas.
-- =============================================================================

-- Tabela de teste: 100 mil "pedidos" com 1000 clientes e datas de 2025-2026.
CREATE TABLE tmp_pedidos_grande AS
SELECT LEVEL                                          AS id_pedido,
       MOD(LEVEL, 1000) + 1                           AS id_cliente,
       DATE '2025-01-01' + MOD(LEVEL * 7, 700)        AS data_pedido,
       CASE MOD(LEVEL, 50) WHEN 0 THEN 'CANCELADO' ELSE 'ENTREGUE' END AS status,
       CASE WHEN MOD(LEVEL, 10) = 0 THEN NULL ELSE 'obs ' || LEVEL END AS observacao,
       'Cliente ' || (MOD(LEVEL, 1000) + 1)           AS nome_cliente
  FROM dual
CONNECT BY LEVEL <= 100000;

ALTER TABLE tmp_pedidos_grande ADD CONSTRAINT pk_tmp_pedidos_grande PRIMARY KEY (id_pedido);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PEDIDOS_GRANDE');
END;
/

-- 1. Sem índice na coluna: leitura completa.
-- Esperado no plano: TABLE ACCESS FULL
EXPLAIN PLAN FOR SELECT * FROM tmp_pedidos_grande WHERE id_cliente = 42;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- 2. Índice composto (id_cliente, data_pedido).
CREATE INDEX tmp_ix_ped_cliente_data ON tmp_pedidos_grande (id_cliente, data_pedido);

BEGIN
    DBMS_STATS.GATHER_INDEX_STATS(USER, 'TMP_IX_PED_CLIENTE_DATA');
END;
/

-- Pela coluna inicial: usa o índice.
-- Esperado: INDEX RANGE SCAN TMP_IX_PED_CLIENTE_DATA
EXPLAIN PLAN FOR SELECT * FROM tmp_pedidos_grande WHERE id_cliente = 42;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- Igualdade + faixa: usa as duas colunas do índice.
-- Esperado: INDEX RANGE SCAN, com access nas duas colunas
EXPLAIN PLAN FOR
SELECT * FROM tmp_pedidos_grande
 WHERE id_cliente = 42 AND data_pedido >= DATE '2026-01-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- Só pela segunda coluna: em geral leitura completa (ou INDEX SKIP SCAN).
EXPLAIN PLAN FOR
SELECT * FROM tmp_pedidos_grande WHERE data_pedido = DATE '2026-01-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- 3. ORDER BY atendido pelo índice: sem operação SORT no plano.
EXPLAIN PLAN FOR
SELECT id_pedido, data_pedido FROM tmp_pedidos_grande
 WHERE id_cliente = 42
 ORDER BY data_pedido;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 4. Função na coluna impede o índice comum; índice baseado em função resolve.
EXPLAIN PLAN FOR SELECT * FROM tmp_pedidos_grande WHERE UPPER(nome_cliente) = 'CLIENTE 42';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
-- Esperado: TABLE ACCESS FULL

CREATE INDEX tmp_ix_ped_nome_upper ON tmp_pedidos_grande (UPPER(nome_cliente));

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PEDIDOS_GRANDE', cascade => TRUE);
END;
/

EXPLAIN PLAN FOR SELECT * FROM tmp_pedidos_grande WHERE UPPER(nome_cliente) = 'CLIENTE 42';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
-- Esperado: INDEX RANGE SCAN TMP_IX_PED_NOME_UPPER

-- 5. IS NULL não usa índice de uma coluna; índice com constante resolve.
CREATE INDEX tmp_ix_ped_obs ON tmp_pedidos_grande (observacao);

EXPLAIN PLAN FOR SELECT COUNT(*) FROM tmp_pedidos_grande WHERE observacao IS NULL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
-- Esperado: TABLE ACCESS FULL (as linhas nulas não estão no índice)

DROP INDEX tmp_ix_ped_obs;
CREATE INDEX tmp_ix_ped_obs ON tmp_pedidos_grande (observacao, 0);

EXPLAIN PLAN FOR SELECT COUNT(*) FROM tmp_pedidos_grande WHERE observacao IS NULL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
-- Esperado: o plano usa TMP_IX_PED_OBS (INDEX RANGE SCAN ou INDEX FAST FULL SCAN):
-- com a constante, toda linha entra no índice, inclusive as de observação nula

-- 6. Índice invisível: mantido, mas ignorado pelo otimizador.
ALTER INDEX tmp_ix_ped_cliente_data INVISIBLE;

EXPLAIN PLAN FOR SELECT * FROM tmp_pedidos_grande WHERE id_cliente = 42;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));
-- Esperado: TABLE ACCESS FULL

ALTER INDEX tmp_ix_ped_cliente_data VISIBLE;

-- 7. Índices da tabela no dicionário.
SELECT i.index_name, i.index_type, i.uniqueness, i.visibility,
       LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_position) AS colunas
  FROM user_indexes     i
  JOIN user_ind_columns c ON c.index_name = i.index_name
 WHERE i.table_name = 'TMP_PEDIDOS_GRANDE'
 GROUP BY i.index_name, i.index_type, i.uniqueness, i.visibility
 ORDER BY i.index_name;
-- O índice baseado em função aparece com uma coluna SYS_NC... (a expressão
-- fica em USER_IND_EXPRESSIONS) e o tipo FUNCTION-BASED NORMAL.

-- Limpeza
DROP TABLE tmp_pedidos_grande PURGE;
