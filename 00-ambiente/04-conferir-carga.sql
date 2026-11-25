-- =============================================================================
-- Tópico : Schema de exemplo — conferência da carga
-- Seção  : 00-ambiente
-- Versão : 19c
-- Requer : 03-carregar-dados.sql
--
-- Toda linha deve sair com situacao = OK. Se alguma sair DIVERGENTE, a carga
-- está incompleta ou os dados foram alterados por algum exemplo; recrie o
-- schema com instalar.sql (ou rode 99, 02 e 03 de novo).
-- =============================================================================

SELECT verificacao,
       encontrado,
       esperado,
       CASE WHEN encontrado = esperado THEN 'OK' ELSE 'DIVERGENTE' END AS situacao
  FROM (
        SELECT 01 AS ordem, 'Linhas em departamentos' AS verificacao,
               (SELECT COUNT(*) FROM departamentos) AS encontrado, 5 AS esperado FROM dual
        UNION ALL
        SELECT 02, 'Linhas em funcionarios',
               (SELECT COUNT(*) FROM funcionarios), 14 FROM dual
        UNION ALL
        SELECT 03, 'Linhas em clientes',
               (SELECT COUNT(*) FROM clientes), 12 FROM dual
        UNION ALL
        SELECT 04, 'Linhas em categorias',
               (SELECT COUNT(*) FROM categorias), 7 FROM dual
        UNION ALL
        SELECT 05, 'Linhas em produtos',
               (SELECT COUNT(*) FROM produtos), 15 FROM dual
        UNION ALL
        SELECT 06, 'Linhas em pedidos',
               (SELECT COUNT(*) FROM pedidos), 24 FROM dual
        UNION ALL
        SELECT 07, 'Linhas em itens_pedido',
               (SELECT COUNT(*) FROM itens_pedido), 54 FROM dual
        UNION ALL
        SELECT 08, 'Funcionarios sem departamento',
               (SELECT COUNT(*) FROM funcionarios WHERE id_departamento IS NULL), 1 FROM dual
        UNION ALL
        SELECT 09, 'Clientes sem pedido',
               (SELECT COUNT(*) FROM clientes c
                 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente)), 2 FROM dual
        UNION ALL
        SELECT 10, 'Produtos nunca vendidos',
               (SELECT COUNT(*) FROM produtos pr
                 WHERE NOT EXISTS (SELECT 1 FROM itens_pedido i WHERE i.id_produto = pr.id_produto)), 1 FROM dual
        UNION ALL
        SELECT 11, 'Pedidos sem vendedor',
               (SELECT COUNT(*) FROM pedidos WHERE id_vendedor IS NULL), 3 FROM dual
        UNION ALL
        SELECT 12, 'Valor liquido total dos itens',
               (SELECT SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2))
                  FROM itens_pedido), 122815.43 FROM dual
       )
 ORDER BY ordem;
