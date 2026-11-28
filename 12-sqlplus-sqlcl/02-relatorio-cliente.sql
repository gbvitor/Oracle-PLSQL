-- =============================================================================
-- Tópico : Script com parâmetro posicional (chamado por 02-executar-scripts.sql)
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus ou SQLcl)
-- Requer : schema de exemplo (00-ambiente)
--
-- Parâmetro 1: id do cliente
-- Chamada   : @02-relatorio-cliente.sql 3
-- =============================================================================

SET VERIFY OFF
SET FEEDBACK OFF

DEFINE p_id_cliente = &1

COLUMN nome   FORMAT A30
COLUMN status FORMAT A10
COLUMN valor  FORMAT 999G990D00

PROMPT
PROMPT Cliente &p_id_cliente

SELECT nome, cidade, uf FROM clientes WHERE id_cliente = &p_id_cliente;

SELECT p.id_pedido,
       p.status,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.id_cliente = &p_id_cliente
 GROUP BY p.id_pedido, p.status
 ORDER BY p.id_pedido;

UNDEFINE p_id_cliente
UNDEFINE 1

SET FEEDBACK ON
SET VERIFY ON
