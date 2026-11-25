-- =============================================================================
-- Tópico : NULL — comparações, expressões, agregações e NOT IN
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Os valores nos comentários valem para a carga original do schema.
-- =============================================================================

-- 1. Comparação com NULL não é verdadeira nem falsa.
--    Quem não tem comissão some dos dois filtros.
-- Esperado: 2
SELECT COUNT(*) AS comissao_igual_5     FROM funcionarios WHERE pct_comissao = 5;
-- Esperado: 3
SELECT COUNT(*) AS comissao_diferente_5 FROM funcionarios WHERE pct_comissao <> 5;
-- Esperado: 9
SELECT COUNT(*) AS comissao_nula        FROM funcionarios WHERE pct_comissao IS NULL;
-- 2 + 3 + 9 = 14 funcionários

-- "= NULL" nunca encontra nada; o certo é IS NULL.
-- Esperado: 0
SELECT COUNT(*) AS igual_null FROM funcionarios WHERE pct_comissao = NULL;

-- 2. Incluindo os nulos no filtro de "diferente".
-- Esperado: 12
SELECT COUNT(*) AS diferente_5_ou_nulo
  FROM funcionarios
 WHERE pct_comissao <> 5 OR pct_comissao IS NULL;

-- Esperado: 12
SELECT COUNT(*) AS diferente_5_com_lnnvl
  FROM funcionarios
 WHERE LNNVL(pct_comissao = 5);

-- 3. Expressões: aritmética propaga NULL; concatenação ignora.
SELECT nome,
       salario,
       pct_comissao,
       salario * pct_comissao / 100           AS comissao_sobre_salario,  -- nulo para quem não vende
       'Comissao: ' || pct_comissao || '%'    AS texto                     -- 'Comissao: %' para quem não vende
  FROM funcionarios
 WHERE id_funcionario IN (100, 104);

-- 4. Agregações ignoram NULL.
SELECT COUNT(*)                          AS funcionarios,              -- 14
       COUNT(pct_comissao)               AS com_comissao,              -- 5
       AVG(pct_comissao)                 AS media_de_quem_tem,         -- 3.8
       ROUND(AVG(NVL(pct_comissao, 0)), 2) AS media_geral,             -- 1.36
       SUM(CASE WHEN id_departamento = 50 THEN salario END) AS soma_vazia  -- nulo, não zero
  FROM funcionarios;

-- Esperado: 12 | 9 | 11
SELECT COUNT(*) AS clientes, COUNT(email) AS com_email, COUNT(limite_credito) AS com_limite
  FROM clientes;

-- 5. GROUP BY junta todos os nulos num grupo só.
-- Esperado: o grupo nulo (estagiário) aparece por último
SELECT id_departamento, COUNT(*) AS funcionarios
  FROM funcionarios
 GROUP BY id_departamento
 ORDER BY id_departamento;

-- 6. Ordenação: NULL por último em ASC; NULLS FIRST inverte.
SELECT nome, pct_comissao FROM funcionarios ORDER BY pct_comissao;
SELECT nome, pct_comissao FROM funcionarios ORDER BY pct_comissao NULLS FIRST;

-- 7. A armadilha do NOT IN.
--    Pergunta: quais funcionários nunca fizeram uma venda?
--    pedidos.id_vendedor tem nulos (vendas pelo site).

-- Errado: não devolve nenhuma linha.
-- Esperado: 0
SELECT COUNT(*) AS com_not_in
  FROM funcionarios f
 WHERE f.id_funcionario NOT IN (SELECT p.id_vendedor FROM pedidos p);

-- Certo: NOT EXISTS não é afetado pelo nulo.
-- Esperado: 9
SELECT COUNT(*) AS com_not_exists
  FROM funcionarios f
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_vendedor = f.id_funcionario);

-- Também certo: tirar o nulo da subquery.
-- Esperado: 9
SELECT COUNT(*) AS com_not_in_filtrado
  FROM funcionarios f
 WHERE f.id_funcionario NOT IN (SELECT p.id_vendedor FROM pedidos p
                                 WHERE p.id_vendedor IS NOT NULL);

-- 8. CASE simples não reconhece NULL; DECODE reconhece.
SELECT CASE NULL WHEN NULL THEN 'igual' ELSE 'diferente' END AS com_case,     -- diferente
       DECODE(NULL, NULL, 'igual', 'diferente')               AS com_decode    -- igual
  FROM dual;

-- 9. UNIQUE aceita vários nulos.
CREATE TABLE tmp_unico (codigo VARCHAR2(10) CONSTRAINT uk_tmp_unico UNIQUE);

INSERT INTO tmp_unico VALUES (NULL);
-- Esperado: aceito
INSERT INTO tmp_unico VALUES (NULL);
INSERT INTO tmp_unico VALUES ('A');
-- Esperado: ORA-00001
INSERT INTO tmp_unico VALUES ('A');

-- Esperado: 3
SELECT COUNT(*) AS linhas FROM tmp_unico;

-- Limpeza
DROP TABLE tmp_unico PURGE;
