-- =============================================================================
-- Tópico : Particionamento — interval, list, pruning, manutenção
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); opção Partitioning habilitada.
--          Confira no passo 0; se der FALSE, o restante do script falha com
--          ORA-00439 (recurso não ativado: Partitioning).
-- =============================================================================

-- 0. A opção está habilitada nesta instalação?
-- Esperado: TRUE
SELECT parameter, value FROM v$option WHERE parameter = 'Partitioning';

-- 1. Interval por mês: a partição de cada mês é criada no primeiro INSERT dele.
CREATE TABLE tmp_pedidos_part (
    id_pedido    NUMBER PRIMARY KEY,
    id_cliente   NUMBER,
    data_pedido  DATE   NOT NULL,
    status       VARCHAR2(12)
)
PARTITION BY RANGE (data_pedido)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(PARTITION p_inicial VALUES LESS THAN (DATE '2025-01-01'));

INSERT INTO tmp_pedidos_part
SELECT id_pedido, id_cliente, data_pedido, status FROM pedidos;
COMMIT;

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PEDIDOS_PART');
END;
/

-- Partições criadas automaticamente (nomes SYS_Pnnn).
-- Esperado: p_inicial (vazia) + 19 partições, uma por mês com pedido
SELECT partition_name, high_value, num_rows
  FROM user_tab_partitions
 WHERE table_name = 'TMP_PEDIDOS_PART'
 ORDER BY partition_position;

-- 2. Partition pruning: o filtro na chave lê só a partição de outubro/2026.
-- Esperado: PARTITION RANGE SINGLE, Pstart = Pstop
EXPLAIN PLAN FOR
SELECT * FROM tmp_pedidos_part
 WHERE data_pedido >= DATE '2026-10-01' AND data_pedido < DATE '2026-11-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PARTITION'));

-- Sem filtro na chave: todas as partições.
-- Esperado: PARTITION RANGE ALL
EXPLAIN PLAN FOR SELECT * FROM tmp_pedidos_part WHERE id_cliente = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PARTITION'));

-- Ler uma partição específica pelo valor da chave.
-- Esperado: 1023 e 1024
SELECT id_pedido FROM tmp_pedidos_part PARTITION FOR (DATE '2026-10-15') ORDER BY 1;

-- 3. Manutenção: apagar um mês inteiro na hora.
--    Com índice global (a PK), UPDATE INDEXES mantém o índice utilizável.
ALTER TABLE tmp_pedidos_part DROP PARTITION FOR (DATE '2025-01-15') UPDATE INDEXES;

-- Esperado: 22 (os 2 pedidos de janeiro/2025 sumiram)
SELECT COUNT(*) FROM tmp_pedidos_part;

-- Esperado: VALID
SELECT index_name, status FROM user_indexes WHERE table_name = 'TMP_PEDIDOS_PART';

-- 4. List: uma partição por status.
CREATE TABLE tmp_pedidos_status (
    id_pedido NUMBER,
    status    VARCHAR2(12)
)
PARTITION BY LIST (status) (
    PARTITION p_abertos    VALUES ('ABERTO', 'FATURADO'),
    PARTITION p_encerrados VALUES ('ENTREGUE', 'CANCELADO'),
    PARTITION p_outros     VALUES (DEFAULT)
);

INSERT INTO tmp_pedidos_status SELECT id_pedido, status FROM pedidos;
COMMIT;

-- Esperado: p_abertos 6 | p_encerrados 18 | p_outros 0
SELECT 'p_abertos'    AS particao, COUNT(*) AS linhas FROM tmp_pedidos_status PARTITION (p_abertos)
UNION ALL
SELECT 'p_encerrados', COUNT(*) FROM tmp_pedidos_status PARTITION (p_encerrados)
UNION ALL
SELECT 'p_outros',     COUNT(*) FROM tmp_pedidos_status PARTITION (p_outros);

-- 5. Mudar a chave move a linha de partição (exige ROW MOVEMENT).
-- Esperado: ORA-14402 (atualizar a coluna de chave de partição faria com que a linha mudasse de partição)
UPDATE tmp_pedidos_status SET status = 'ENTREGUE' WHERE id_pedido = 1022;

ALTER TABLE tmp_pedidos_status ENABLE ROW MOVEMENT;

-- Esperado: 1 linha atualizada
UPDATE tmp_pedidos_status SET status = 'ENTREGUE' WHERE id_pedido = 1022;
ROLLBACK;

-- Limpeza
DROP TABLE tmp_pedidos_status PURGE;
DROP TABLE tmp_pedidos_part PURGE;
