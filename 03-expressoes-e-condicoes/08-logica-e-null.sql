-- =============================================================================
-- Tópico : AND, OR, NOT, IS NULL, LNNVL e parênteses
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Comissões: 104 e 105 = 5, 106 = 4, 107 = 3, 108 = 2, os outros 9 = nulo.
-- =============================================================================

-- 1. Uma condição e sua negação não somam o total quando há NULL.
-- Esperado: 3 | 2 | 9 nulos que não aparecem em nenhum dos dois
SELECT (SELECT COUNT(*) FROM funcionarios WHERE pct_comissao > 3)        AS maior_que_3,
       (SELECT COUNT(*) FROM funcionarios WHERE NOT (pct_comissao > 3))  AS negacao,
       (SELECT COUNT(*) FROM funcionarios WHERE pct_comissao IS NULL)    AS nulos
  FROM dual;

-- 2. Incluindo os nulos na negação.
-- Esperado: 11 | 11
SELECT (SELECT COUNT(*) FROM funcionarios
         WHERE NOT (pct_comissao > 3) OR pct_comissao IS NULL) AS com_or_is_null,
       (SELECT COUNT(*) FROM funcionarios
         WHERE LNNVL(pct_comissao > 3))                        AS com_lnnvl
  FROM dual;

-- 3. Tabela-verdade: a coluna "resultado" mostra TRUE, FALSE ou UNKNOWN.
WITH valores AS (
    SELECT 'TRUE'    AS a, 1    AS va FROM dual UNION ALL
    SELECT 'FALSE',        0          FROM dual UNION ALL
    SELECT 'UNKNOWN',      NULL       FROM dual
)
SELECT x.a AS a,
       y.a AS b,
       CASE WHEN x.va = 1 AND y.va = 1 THEN 'TRUE'
            WHEN NOT (x.va = 1 AND y.va = 1) THEN 'FALSE'
            ELSE 'UNKNOWN' END AS a_and_b,
       CASE WHEN x.va = 1 OR y.va = 1 THEN 'TRUE'
            WHEN NOT (x.va = 1 OR y.va = 1) THEN 'FALSE'
            ELSE 'UNKNOWN' END AS a_or_b
  FROM valores x CROSS JOIN valores y
 ORDER BY x.a, y.a;

-- 4. Precedência: AND antes de OR.
-- Esperado: 4 (os 3 ABERTO de qualquer cliente + 1 FATURADO do cliente 2)
SELECT COUNT(*) AS sem_parenteses
  FROM pedidos
 WHERE status = 'ABERTO' OR status = 'FATURADO' AND id_cliente = 2;

-- Esperado: 1 (só o FATURADO 1021 do cliente 2; o cliente 2 não tem ABERTO)
SELECT COUNT(*) AS com_parenteses
  FROM pedidos
 WHERE (status = 'ABERTO' OR status = 'FATURADO') AND id_cliente = 2;

-- 5. De Morgan: "nem SP nem MG", três formas equivalentes.
-- Esperado: 8 | 8 | 8
SELECT (SELECT COUNT(*) FROM clientes WHERE NOT (uf = 'SP' OR uf = 'MG'))  AS forma_1,
       (SELECT COUNT(*) FROM clientes WHERE uf <> 'SP' AND uf <> 'MG')     AS forma_2,
       (SELECT COUNT(*) FROM clientes WHERE uf NOT IN ('SP', 'MG'))        AS forma_3
  FROM dual;

-- 6. IS NULL e IS NOT NULL em colunas opcionais.
-- Esperado: 3 sem email | 1 sem limite | 3 pedidos pelo site
SELECT (SELECT COUNT(*) FROM clientes WHERE email IS NULL)          AS clientes_sem_email,
       (SELECT COUNT(*) FROM clientes WHERE limite_credito IS NULL) AS clientes_sem_limite,
       (SELECT COUNT(*) FROM pedidos  WHERE id_vendedor IS NULL)    AS pedidos_site
  FROM dual;
