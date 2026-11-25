-- =============================================================================
-- Tópico : FROM — tabelas, aliases, inline views, coleções, LATERAL
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Alias de tabela sem AS.
SELECT c.nome, c.uf
  FROM clientes c
 WHERE c.uf = 'SP';

-- Com AS: erro no Oracle.
-- Esperado: ORA-00933 (comando SQL não encerrado adequadamente)
SELECT c.nome
  FROM clientes AS c;

-- Depois do alias, o nome da tabela não serve mais para qualificar.
-- Esperado: ORA-00904 ("CLIENTES"."NOME": identificador inválido)
SELECT clientes.nome
  FROM clientes c;

-- 2. Inline view: agregar primeiro, filtrar depois.
-- Esperado: cliente 1 (4 pedidos); clientes 2, 3, 6 e 10 (3 pedidos cada)
SELECT v.id_cliente, v.qtd_pedidos
  FROM (SELECT id_cliente, COUNT(*) AS qtd_pedidos
          FROM pedidos
         GROUP BY id_cliente) v
 WHERE v.qtd_pedidos >= 3
 ORDER BY v.qtd_pedidos DESC, v.id_cliente;

-- 3. Inline view para fixar a granularidade antes do join:
--    valor por pedido (itens somados) ligado ao cliente.
SELECT p.id_pedido,
       c.nome      AS cliente,
       t.valor_pedido
  FROM pedidos  p
  JOIN clientes c ON c.id_cliente = p.id_cliente
  JOIN (SELECT id_pedido,
               SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)) AS valor_pedido
          FROM itens_pedido
         GROUP BY id_pedido) t
    ON t.id_pedido = p.id_pedido
 ORDER BY t.valor_pedido DESC
 FETCH FIRST 5 ROWS ONLY;

-- 4. Expressão sem alias na inline view não pode ser referenciada de fora.
-- Esperado: ORA-00904 ("QTD": identificador inválido)
SELECT qtd
  FROM (SELECT COUNT(*) FROM pedidos);

-- 5. Produto cartesiano por esquecimento da condição de join.
-- Esperado: 288 (12 clientes x 24 pedidos)
SELECT COUNT(*) AS linhas
  FROM clientes c, pedidos p;

-- 6. Coleção como tabela: lista de valores sem criar tabela.
--    SYS.ODCINUMBERLIST e SYS.ODCIVARCHAR2LIST existem em todo banco Oracle.
SELECT t.COLUMN_VALUE AS uf
  FROM TABLE(SYS.ODCIVARCHAR2LIST('SP', 'MG', 'AM')) t;

-- Usada para conferir quais UFs da lista têm cliente.
-- Esperado: AM 0, MG 1, SP 3
SELECT t.COLUMN_VALUE AS uf,
       (SELECT COUNT(*) FROM clientes c WHERE c.uf = t.COLUMN_VALUE) AS clientes
  FROM TABLE(SYS.ODCIVARCHAR2LIST('SP', 'MG', 'AM')) t
 ORDER BY 1;

-- 7. LATERAL: a subquery enxerga a tabela que vem antes no FROM.
--    Último pedido de cada cliente que tem pedido.
-- Esperado: 10 linhas; cliente 1 -> 1022, cliente 6 -> 1024
SELECT c.id_cliente, c.nome, u.id_pedido, u.data_pedido
  FROM clientes c,
       LATERAL (SELECT p.id_pedido, p.data_pedido
                  FROM pedidos p
                 WHERE p.id_cliente = c.id_cliente
                 ORDER BY p.data_pedido DESC
                 FETCH FIRST 1 ROW ONLY) u
 ORDER BY c.id_cliente;
