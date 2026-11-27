-- =============================================================================
-- Tópico : Sintaxe de join antiga com (+) [legado]
-- Seção  : 05-consultas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Cada consulta antiga vem seguida do equivalente ANSI.
-- =============================================================================

-- 1. Inner join.
-- Esperado: 24 | 24
SELECT (SELECT COUNT(*) FROM clientes c, pedidos p
         WHERE p.id_cliente = c.id_cliente)                       AS antigo,
       (SELECT COUNT(*) FROM clientes c
          JOIN pedidos p ON p.id_cliente = c.id_cliente)          AS ansi
  FROM dual;

-- 2. Left join: (+) do lado da tabela opcional.
-- Esperado: 26 | 26 (24 pedidos + 2 clientes sem pedido)
SELECT (SELECT COUNT(*) FROM clientes c, pedidos p
         WHERE p.id_cliente (+) = c.id_cliente)                   AS antigo,
       (SELECT COUNT(*) FROM clientes c
          LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente)     AS ansi
  FROM dual;

-- 3. Filtro sobre a tabela opcional COM (+): continua outer.
-- Esperado: 12 | 12
SELECT (SELECT COUNT(*) FROM clientes c, pedidos p
         WHERE p.id_cliente (+) = c.id_cliente
           AND p.status     (+) = 'ABERTO')                        AS antigo,
       (SELECT COUNT(*) FROM clientes c
          LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
                             AND p.status     = 'ABERTO')          AS ansi
  FROM dual;

-- 4. Filtro sobre a tabela opcional SEM (+): vira inner.
-- Esperado: 3 | 3
SELECT (SELECT COUNT(*) FROM clientes c, pedidos p
         WHERE p.id_cliente (+) = c.id_cliente
           AND p.status         = 'ABERTO')                        AS antigo,
       (SELECT COUNT(*) FROM clientes c
          LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
         WHERE p.status = 'ABERTO')                                AS ansi
  FROM dual;

-- 5. Três tabelas com outer join em cadeia.
--    Pedido -> vendedor (opcional) -> departamento do vendedor (opcional).
SELECT p.id_pedido, f.nome AS vendedor, d.nome AS departamento
  FROM pedidos p, funcionarios f, departamentos d
 WHERE f.id_funcionario  (+) = p.id_vendedor
   AND d.id_departamento (+) = f.id_departamento
 ORDER BY p.id_pedido;

SELECT p.id_pedido, f.nome AS vendedor, d.nome AS departamento
  FROM pedidos p
  LEFT JOIN funcionarios  f ON f.id_funcionario  = p.id_vendedor
  LEFT JOIN departamentos d ON d.id_departamento = f.id_departamento
 ORDER BY p.id_pedido;

-- 6. (+) com OR não é permitido.
-- Esperado: ORA-01719 (operador de junção externa (+) não permitido no operando de OR ou IN)
SELECT c.nome, p.id_pedido
  FROM clientes c, pedidos p
 WHERE p.id_cliente (+) = c.id_cliente
   AND (p.status (+) = 'ABERTO' OR p.status (+) = 'FATURADO');

-- Em ANSI, sem restrição.
SELECT c.nome, p.id_pedido
  FROM clientes c
  LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
                     AND p.status IN ('ABERTO', 'FATURADO')
 ORDER BY c.nome;

-- 7. FULL OUTER JOIN não existe com (+): contorno antigo com UNION.
-- Esperado: 15 | 15
SELECT (SELECT COUNT(*) FROM (
            SELECT d.id_departamento, f.id_funcionario
              FROM departamentos d, funcionarios f
             WHERE f.id_departamento (+) = d.id_departamento
            UNION
            SELECT d.id_departamento, f.id_funcionario
              FROM departamentos d, funcionarios f
             WHERE f.id_departamento = d.id_departamento (+)))    AS antigo,
       (SELECT COUNT(*) FROM departamentos d
          FULL JOIN funcionarios f ON f.id_departamento = d.id_departamento) AS ansi
  FROM dual;
