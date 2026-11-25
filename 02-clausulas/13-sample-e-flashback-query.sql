-- =============================================================================
-- Tópico : SAMPLE e Flashback Query (AS OF)
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); SELECT em V$DATABASE (o usuário
--          de estudo tem). Os passos 4 a 8 usam COLUMN ... NEW_VALUE do
--          SQL*Plus/SQLcl para guardar o SCN sem digitação manual.
-- O passo 7 restaura o preço alterado; o schema volta ao estado original.
-- =============================================================================

-- 1. Amostra de ~25% das linhas: muda a cada execução.
SELECT COUNT(*) AS linhas_na_amostra FROM pedidos SAMPLE (25);
SELECT COUNT(*) AS linhas_na_amostra FROM pedidos SAMPLE (25);

-- 2. Com SEED, a mesma amostra se repete.
SELECT id_pedido FROM pedidos SAMPLE (25) SEED (7) ORDER BY id_pedido;
SELECT id_pedido FROM pedidos SAMPLE (25) SEED (7) ORDER BY id_pedido;

-- 3. N linhas aleatórias exatas (lê a tabela toda).
-- Esperado: sempre 3 linhas, diferentes a cada execução
SELECT id_pedido, data_pedido
  FROM pedidos
 ORDER BY DBMS_RANDOM.VALUE
 FETCH FIRST 3 ROWS ONLY;

-- 4. Guardar o SCN atual numa variável do SQL*Plus.
COLUMN scn_antes NEW_VALUE scn_antes
SELECT current_scn AS scn_antes FROM v$database;

-- 5. "Erro" proposital: preço do produto 3 zerado e confirmado.
UPDATE produtos SET preco_unitario = 0 WHERE id_produto = 3;
COMMIT;

-- Esperado: 0
SELECT preco_unitario AS preco_atual FROM produtos WHERE id_produto = 3;

-- 6. O valor no SCN guardado.
-- Esperado: 899
SELECT preco_unitario AS preco_no_passado
  FROM produtos AS OF SCN &scn_antes
 WHERE id_produto = 3;

-- Comparação: linhas que mudaram desde o SCN guardado.
-- Esperado: só o produto 3
SELECT id_produto, nome, preco_unitario FROM produtos AS OF SCN &scn_antes
MINUS
SELECT id_produto, nome, preco_unitario FROM produtos;

-- 7. Recuperar o valor a partir do passado.
UPDATE produtos p
   SET preco_unitario = (SELECT a.preco_unitario
                           FROM produtos AS OF SCN &scn_antes a
                          WHERE a.id_produto = p.id_produto)
 WHERE p.id_produto = 3;
COMMIT;

-- Esperado: 899
SELECT preco_unitario AS preco_restaurado FROM produtos WHERE id_produto = 3;

-- Garantia: se algum passo anterior falhou (por exemplo, sem acesso a
-- V$DATABASE), devolve o preço original do schema de exemplo.
UPDATE produtos SET preco_unitario = 899 WHERE id_produto = 3 AND preco_unitario = 0;
COMMIT;

-- 8. AS OF TIMESTAMP: a mesma ideia com horário em vez de SCN.
--    Resolução de alguns segundos: para mudanças muito recentes, prefira SCN.
SELECT COUNT(*) AS pedidos_ha_5_minutos
  FROM pedidos AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '5' MINUTE);
