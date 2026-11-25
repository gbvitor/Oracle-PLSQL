-- =============================================================================
-- Tópico : WHERE — filtros, precedência, datas e índice
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Filtros combinados.
-- Esperado: 1001, 1006, 1015
SELECT id_pedido, data_pedido, status
  FROM pedidos
 WHERE id_cliente = 1
   AND status = 'ENTREGUE'
 ORDER BY id_pedido;

-- 2. Precedência: AND antes de OR.
--    Sem parênteses: todos os ENTREGUE + os FATURADO do cliente 1.
-- Esperado: 17
SELECT COUNT(*) AS sem_parenteses
  FROM pedidos
 WHERE status = 'ENTREGUE' OR status = 'FATURADO' AND id_cliente = 1;

-- Com parênteses: ENTREGUE ou FATURADO, só do cliente 1.
-- Esperado: 3
SELECT COUNT(*) AS com_parenteses
  FROM pedidos
 WHERE (status = 'ENTREGUE' OR status = 'FATURADO') AND id_cliente = 1;

-- 3. BETWEEN com DATE perde o último dia.
--    O pedido 1024 é de 30/10/2026 às 20:30.
-- Esperado: só 1023
SELECT id_pedido, TO_CHAR(data_pedido, 'DD/MM/YYYY HH24:MI') AS data_hora
  FROM pedidos
 WHERE data_pedido BETWEEN DATE '2026-10-01' AND DATE '2026-10-30';

-- Intervalo semiaberto: correto e usa índice.
-- Esperado: 1023 e 1024
SELECT id_pedido, TO_CHAR(data_pedido, 'DD/MM/YYYY HH24:MI') AS data_hora
  FROM pedidos
 WHERE data_pedido >= DATE '2026-10-01'
   AND data_pedido <  DATE '2026-11-01';

-- 4. Função na coluna impede o índice IX_PEDIDOS_DATA.
--    Comparar os planos: o primeiro faz TABLE ACCESS FULL, o segundo
--    INDEX RANGE SCAN (numa tabela tão pequena, o otimizador pode preferir
--    FULL nos dois; o ponto é que no primeiro ele não tem escolha).
EXPLAIN PLAN FOR
SELECT id_pedido FROM pedidos WHERE TRUNC(data_pedido) = DATE '2026-10-14';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

EXPLAIN PLAN FOR
SELECT id_pedido FROM pedidos
 WHERE data_pedido >= DATE '2026-10-14' AND data_pedido < DATE '2026-10-15';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 5. Conversão implícita: número comparado com coluna de texto.
--    O plano mostra o filtro como TO_NUMBER("DOCUMENTO")=10000000000101.
EXPLAIN PLAN FOR
SELECT nome FROM clientes WHERE documento = 10000000000101;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- Comparando com texto, o índice único UK_CLIENTES_DOCUMENTO pode ser usado.
EXPLAIN PLAN FOR
SELECT nome FROM clientes WHERE documento = '10000000000101';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- 6. A conversão implícita quebra quando aparece um valor não numérico.
UPDATE clientes SET documento = '1000000000010X' WHERE id_cliente = 11;

-- Esperado: ORA-01722 (número inválido)
SELECT nome FROM clientes WHERE documento = 10000000000101;

ROLLBACK;

-- 7. Filtro em expressão sobre a coluna versus na coluna pura.
-- Esperado: 4 nos dois
SELECT COUNT(*) FROM funcionarios WHERE salario * 12 > 100000;
SELECT COUNT(*) FROM funcionarios WHERE salario > 100000 / 12;
