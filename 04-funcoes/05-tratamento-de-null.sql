-- =============================================================================
-- Tópico : NVL, NVL2, COALESCE, NULLIF, LNNVL
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. NVL e NVL2.
SELECT nome,
       pct_comissao,
       NVL(pct_comissao, 0)                          AS comissao_ou_zero,
       NVL2(pct_comissao, 'comissionado', 'fixo')    AS regime
  FROM funcionarios
 ORDER BY pct_comissao NULLS LAST, nome;

-- 2. NVL converte o segundo argumento para o tipo do primeiro.
-- Esperado: ORA-01722 (número inválido)
SELECT NVL(pct_comissao, 'sem comissao') FROM funcionarios;

-- COALESCE exige tipos compatíveis.
-- Esperado: ORA-00932 (tipos de dados inconsistentes)
SELECT COALESCE(pct_comissao, 'sem comissao') FROM funcionarios;

-- Certo: converter o número.
SELECT nome, NVL(TO_CHAR(pct_comissao) || '%', 'sem comissao') AS comissao
  FROM funcionarios;

-- 3. COALESCE com vários níveis de fallback.
--    Contato: e-mail; se não houver, documento; se não houver, aviso.
SELECT id_cliente,
       COALESCE(email, 'doc ' || documento, 'sem contato') AS contato
  FROM clientes
 ORDER BY id_cliente;
-- clientes 3, 7 e 11 aparecem com "doc ..."

-- 4. NVL avalia os dois argumentos; COALESCE para no primeiro não nulo.
--    O segundo argumento divide por zero (id - id = 0) em toda linha.
-- Esperado: ORA-01476 (divisor é igual a zero)
SELECT NVL(salario, 1 / (id_funcionario - id_funcionario)) FROM funcionarios;

-- Esperado: 14 linhas, sem erro (salario nunca é nulo)
SELECT COALESCE(salario, 1 / (id_funcionario - id_funcionario)) AS salario FROM funcionarios;

-- 5. NULLIF: divisão segura e valor "vazio" virando NULL.
-- Esperado: nulo | nulo | Entregar no 3o andar
SELECT 100 / NULLIF(0, 0)                    AS divisao_segura,
       NULLIF(TRIM('  -  '), '-')            AS traco_vira_nulo,
       NULLIF('Entregar no 3o andar', '-')   AS texto_mantido
  FROM dual;

-- Preço médio por unidade em cada pedido, sem quebrar se a soma de
-- quantidades fosse zero.
SELECT id_pedido,
       ROUND(SUM(quantidade * preco_unitario) / NULLIF(SUM(quantidade), 0), 2) AS preco_medio
  FROM itens_pedido
 GROUP BY id_pedido
 ORDER BY id_pedido
 FETCH FIRST 5 ROWS ONLY;

-- 6. LNNVL: negar sem perder os nulos.
-- Esperado: 2 | 11
SELECT (SELECT COUNT(*) FROM funcionarios WHERE NOT (pct_comissao > 3)) AS not_perde_nulos,
       (SELECT COUNT(*) FROM funcionarios WHERE LNNVL(pct_comissao > 3)) AS lnnvl_inclui
  FROM dual;

-- 7. Trocar NULL por zero muda a pergunta.
-- Esperado: 3.8 (média de quem tem comissão) | 1.36 (média de todos)
SELECT AVG(pct_comissao)                    AS media_comissionados,
       ROUND(AVG(NVL(pct_comissao, 0)), 2)  AS media_todos
  FROM funcionarios;
