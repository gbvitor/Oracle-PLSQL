-- =============================================================================
-- Tópico : Quando o índice é usado e quando é ignorado — função na coluna,
--          conversão implícita, curinga, desigualdade, clustering factor
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql (sem histograma em status)
--
-- Cada par mostra a forma que impede o índice e a forma que o usa. O que importa
-- é a operação e a seção de predicados; custos variam.
-- =============================================================================

SET LINESIZE 200
SET PAGESIZE 200

-- 1. Função na coluna.
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE TRUNC(data_pedido) = DATE '2025-03-10';
-- Esperado: TABLE ACCESS FULL, filter(TRUNC(INTERNAL_FUNCTION("DATA_PEDIDO"))=...);
--           Rows estimado ~2000 (1% padrão para função sobre coluna), real 274
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor) FROM tmp_perf_pedidos
 WHERE data_pedido >= DATE '2025-03-10' AND data_pedido < DATE '2025-03-11';
-- Esperado: INDEX RANGE SCAN TMP_IX_PERF_PED_DATA, access("DATA_PEDIDO">=... AND "DATA_PEDIDO"<...)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- Os dois devolvem o mesmo resultado.
-- Esperado: 274 nas duas
SELECT (SELECT COUNT(*) FROM tmp_perf_pedidos WHERE TRUNC(data_pedido) = DATE '2025-03-10') AS com_trunc,
       (SELECT COUNT(*) FROM tmp_perf_pedidos
         WHERE data_pedido >= DATE '2025-03-10' AND data_pedido < DATE '2025-03-11') AS com_faixa
  FROM dual;

-- 2. Expressão na coluna.
EXPLAIN PLAN FOR SELECT * FROM tmp_perf_pedidos WHERE id_pedido + 0 = 4242;
-- Esperado: TABLE ACCESS FULL, filter("ID_PEDIDO"+0=4242)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 3. Conversão implícita: coluna VARCHAR2 comparada com número.
EXPLAIN PLAN FOR SELECT * FROM tmp_perf_clientes WHERE codigo_ext = 100042;
-- Esperado: TABLE ACCESS FULL, filter(TO_NUMBER("CODIGO_EXT")=100042)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

EXPLAIN PLAN FOR SELECT * FROM tmp_perf_clientes WHERE codigo_ext = '100042';
-- Esperado: INDEX RANGE SCAN TMP_IX_PERF_CLI_CODIGO, access("CODIGO_EXT"='100042')
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- O inverso não atrapalha: coluna NUMBER com texto. Só o valor é convertido.
EXPLAIN PLAN FOR SELECT * FROM tmp_perf_clientes WHERE id_cliente = '42';
-- Esperado: INDEX UNIQUE SCAN PK_TMP_PERF_CLIENTES, access("ID_CLIENTE"=42)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- O risco além do desempenho: um valor não numérico quebra a consulta inteira.
UPDATE tmp_perf_clientes SET codigo_ext = 'X-2000' WHERE id_cliente = 2000;

-- Esperado: ORA-01722 (número inválido), mesmo procurando outro cliente
SELECT * FROM tmp_perf_clientes WHERE codigo_ext = 100042;

-- Esperado: 1 linha (a comparação como texto não converte nada)
SELECT id_cliente, nome FROM tmp_perf_clientes WHERE codigo_ext = '100042';

ROLLBACK;

-- 4. Curinga no início.
EXPLAIN PLAN FOR SELECT * FROM tmp_perf_clientes WHERE codigo_ext LIKE '10004%';
-- Esperado: INDEX RANGE SCAN TMP_IX_PERF_CLI_CODIGO, access("CODIGO_EXT" LIKE '10004%')
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

EXPLAIN PLAN FOR SELECT * FROM tmp_perf_clientes WHERE codigo_ext LIKE '%42';
-- Esperado: TABLE ACCESS FULL, filter("CODIGO_EXT" LIKE '%42')
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 5. Desigualdade versus lista do que se quer.
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status <> 'ENTREGUE';
-- Esperado: TABLE ACCESS FULL, filter("STATUS"<>'ENTREGUE'), Rows ~133333 (2/3 da tabela)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

EXPLAIN PLAN FOR SELECT COUNT(*), SUM(valor) FROM tmp_perf_pedidos WHERE status IN ('ABERTO', 'CANCELADO');
-- Esperado: ainda TABLE ACCESS FULL, Rows ~133333: sem histograma, cada status "vale" 1/3.
--           Com o histograma do tópico 05, a estimativa cai para 2200 e o plano vira
--           INLIST ITERATOR + INDEX RANGE SCAN. A forma da condição e a estatística
--           precisam estar certas juntas.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 6. Mesma quantidade de linhas, planos diferentes: o clustering factor.
-- Esperado: PK_TMP_PERF_PEDIDOS com clustering_factor perto de BLOCKS (dados em ordem);
--           TMP_IX_PERF_PED_DATA e TMP_IX_PERF_PED_CLIENTE perto de NUM_ROWS (espalhados)
SELECT i.index_name, i.clustering_factor, t.blocks, t.num_rows
  FROM user_indexes i
  JOIN user_tables t ON t.table_name = i.table_name
 WHERE i.table_name = 'TMP_PERF_PEDIDOS'
 ORDER BY i.clustering_factor;

-- 10% da tabela pela PK (dados em ordem):
EXPLAIN PLAN FOR SELECT SUM(valor) FROM tmp_perf_pedidos WHERE id_pedido BETWEEN 1 AND 20000;
-- Esperado: INDEX RANGE SCAN PK_TMP_PERF_PEDIDOS + TABLE ACCESS BY INDEX ROWID BATCHED
--           (as 20000 linhas estão em ~10% dos blocos, vizinhos)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));

-- 10% da tabela pela data (dados espalhados):
EXPLAIN PLAN FOR
SELECT SUM(valor) FROM tmp_perf_pedidos WHERE data_pedido >= DATE '2024-01-01' AND data_pedido < DATE '2024-03-14';
-- Esperado: TABLE ACCESS FULL (as ~20000 linhas estão espalhadas por quase todos os blocos)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));
