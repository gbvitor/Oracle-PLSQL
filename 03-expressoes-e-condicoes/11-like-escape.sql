-- =============================================================================
-- Tópico : LIKE e ESCAPE
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Prefixo, sufixo e conteúdo.
-- Esperado: 1 cliente começa com "Papel" (Papelaria Central Ltda)
SELECT nome FROM clientes WHERE nome LIKE 'Papel%';

-- Esperado: 4 clientes terminam com "Ltda" (1, 6, 8, 10)
SELECT id_cliente, nome FROM clientes WHERE nome LIKE '%Ltda' ORDER BY id_cliente;

-- Esperado: 2 produtos contêm "Cadeira"
SELECT nome FROM produtos WHERE nome LIKE '%Cadeira%' ORDER BY nome;

-- 2. Underscore: exatamente um caractere.
--    UFs que começam com "P": PE, PR.
-- Esperado: PE, PR
SELECT DISTINCT uf FROM clientes WHERE uf LIKE 'P_' ORDER BY uf;

-- 3. Maiúsculas e minúsculas.
-- Esperado: 0 | 1
SELECT (SELECT COUNT(*) FROM clientes WHERE nome LIKE 'papel%')        AS sensivel,
       (SELECT COUNT(*) FROM clientes WHERE UPPER(nome) LIKE 'PAPEL%') AS com_upper
  FROM dual;

-- 4. ESCAPE para procurar % e _ como texto.
WITH textos AS (
    SELECT 'desconto de 50% no item' AS descricao FROM dual UNION ALL
    SELECT 'desconto de 50 reais'               FROM dual UNION ALL
    SELECT 'codigo_interno'                     FROM dual UNION ALL
    SELECT 'codigo interno'                     FROM dual
)
SELECT descricao,
       CASE WHEN descricao LIKE '%50\%%' ESCAPE '\' THEN 'sim' END AS contem_50_porcento,
       CASE WHEN descricao LIKE '%\_%'   ESCAPE '\' THEN 'sim' END AS contem_underscore,
       CASE WHEN descricao LIKE '%_%'                THEN 'sim' END AS sem_escape
  FROM textos;
-- contem_50_porcento: só a 1a | contem_underscore: só a 3a | sem_escape: todas

-- 5. NULL não casa nem com '%'.
-- Esperado: 9 (12 clientes menos 3 sem email)
SELECT COUNT(*) AS com_email
  FROM clientes
 WHERE email LIKE '%';

-- 6. Prefixo fixo permite busca por faixa no índice (INDEX RANGE SCAN);
--    com % no início, no máximo uma leitura completa (TABLE ACCESS FULL ou
--    INDEX FULL/FAST FULL SCAN). Numa tabela de 12 linhas o otimizador pode
--    preferir leitura completa nos dois casos.
--    Índice só para o exemplo.
CREATE INDEX tmp_ix_clientes_nome ON clientes (nome);

EXPLAIN PLAN FOR SELECT nome FROM clientes WHERE nome LIKE 'Papel%';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

EXPLAIN PLAN FOR SELECT nome FROM clientes WHERE nome LIKE '%Ltda';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

DROP INDEX tmp_ix_clientes_nome;
