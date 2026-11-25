-- =============================================================================
-- Tópico : ORDER BY — direção, NULLs, desempate, ordem personalizada, texto
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Várias colunas, cada uma com sua direção.
SELECT uf, cidade, nome
  FROM clientes
 ORDER BY uf, cidade DESC, nome;

-- 2. NULLs: por último em ASC, primeiro em DESC.
SELECT nome, pct_comissao FROM funcionarios ORDER BY pct_comissao DESC;

-- Comissão decrescente, mas quem não tem comissão por último.
SELECT nome, pct_comissao FROM funcionarios ORDER BY pct_comissao DESC NULLS LAST;

-- 3. Alias, expressão e coluna fora do SELECT.
SELECT nome, salario * 12 AS anual
  FROM funcionarios
 ORDER BY anual DESC;

SELECT nome
  FROM funcionarios
 ORDER BY data_admissao;

-- 4. Com DISTINCT, só colunas do resultado.
-- Esperado: ORA-01791 (não é uma expressão selecionada)
SELECT DISTINCT uf FROM clientes ORDER BY cidade;

-- 5. Desempate: dois clientes em Sao Paulo.
--    Ordenando só por cidade, a ordem entre eles não é garantida.
SELECT cidade, nome, id_cliente
  FROM clientes
 ORDER BY cidade;

-- Com a chave no fim, a ordem fica estável.
SELECT cidade, nome, id_cliente
  FROM clientes
 ORDER BY cidade, id_cliente;

-- 6. Ordem de negócio com CASE.
-- Esperado: ABERTO primeiro, CANCELADO por último
SELECT id_pedido, status, data_pedido
  FROM pedidos
 ORDER BY CASE status
              WHEN 'ABERTO'    THEN 1
              WHEN 'FATURADO'  THEN 2
              WHEN 'ENTREGUE'  THEN 3
              WHEN 'CANCELADO' THEN 4
          END,
          data_pedido DESC;

-- 7. Ordenação binária versus linguística.
--    Lista montada com UNISTR para não depender da codificação do cliente:
--    'Ágata' (com acento), 'banana' (minúscula), 'Abacate', 'Zebra'.
WITH palavras AS (
    SELECT UNISTR('\00C1gata') AS palavra FROM dual UNION ALL
    SELECT 'banana'  FROM dual UNION ALL
    SELECT 'Abacate' FROM dual UNION ALL
    SELECT 'Zebra'   FROM dual
)
SELECT palavra,
       ROW_NUMBER() OVER (ORDER BY palavra)                                  AS ordem_binaria,
       ROW_NUMBER() OVER (ORDER BY NLSSORT(palavra, 'NLS_SORT = BINARY_AI')) AS ordem_linguistica
  FROM palavras
 ORDER BY ordem_binaria;
-- Binária:     Abacate, Zebra, banana, Ágata
-- Linguística: Abacate, Ágata, banana, Zebra

-- 8. Número guardado como texto ordena como texto.
WITH codigos AS (
    SELECT '1' AS codigo FROM dual UNION ALL
    SELECT '10'  FROM dual UNION ALL
    SELECT '2'   FROM dual UNION ALL
    SELECT '100' FROM dual
)
SELECT codigo,
       ROW_NUMBER() OVER (ORDER BY codigo)            AS como_texto,
       ROW_NUMBER() OVER (ORDER BY TO_NUMBER(codigo)) AS como_numero
  FROM codigos
 ORDER BY como_numero;
-- como_texto: 1, 10, 100, 2
