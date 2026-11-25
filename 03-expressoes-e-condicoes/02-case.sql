-- =============================================================================
-- Tópico : CASE simples e pesquisado
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. CASE simples.
SELECT nome,
       CASE tipo_pessoa
           WHEN 'F' THEN 'Pessoa fisica'
           WHEN 'J' THEN 'Pessoa juridica'
           ELSE 'Nao informado'
       END AS tipo
  FROM clientes
 ORDER BY tipo, nome;

-- 2. CASE pesquisado: faixas salariais.
-- Esperado: ate 3 mil 2 | 3 a 6 mil 6 | 6 a 10 mil 2 | 10 mil ou mais 4
SELECT CASE
           WHEN salario <  3000 THEN '1. ate 3 mil'
           WHEN salario <  6000 THEN '2. 3 a 6 mil'
           WHEN salario < 10000 THEN '3. 6 a 10 mil'
           ELSE '4. 10 mil ou mais'
       END       AS faixa,
       COUNT(*)  AS funcionarios
  FROM funcionarios
 GROUP BY CASE
              WHEN salario <  3000 THEN '1. ate 3 mil'
              WHEN salario <  6000 THEN '2. 3 a 6 mil'
              WHEN salario < 10000 THEN '3. 6 a 10 mil'
              ELSE '4. 10 mil ou mais'
          END
 ORDER BY faixa;

-- 3. Ordem errada das condições: a faixa "alto" nunca é atingida.
-- Esperado: medio 12 | baixo 2 | alto nenhum
SELECT CASE
           WHEN salario > 3000  THEN 'medio'
           WHEN salario > 10000 THEN 'alto'
           ELSE 'baixo'
       END       AS faixa,
       COUNT(*)  AS funcionarios
  FROM funcionarios
 GROUP BY CASE
              WHEN salario > 3000  THEN 'medio'
              WHEN salario > 10000 THEN 'alto'
              ELSE 'baixo'
          END;

-- 4. Tipos incompatíveis entre os ramos.
-- Esperado: ORA-00932 (tipos de dados inconsistentes)
SELECT CASE WHEN pct_comissao IS NULL THEN 'sem comissao' ELSE pct_comissao END
  FROM funcionarios;

-- Correto: converter o número para texto.
SELECT nome,
       CASE WHEN pct_comissao IS NULL THEN 'sem comissao'
            ELSE TO_CHAR(pct_comissao) || '%'
       END AS comissao
  FROM funcionarios;

-- 5. Sem ELSE, o resultado é NULL.
-- Esperado: 9 linhas com "faixa" nula (quem não tem comissão)
SELECT COUNT(*) AS sem_faixa
  FROM (SELECT CASE WHEN pct_comissao >= 4 THEN 'alta'
                    WHEN pct_comissao <  4 THEN 'baixa'
               END AS faixa
          FROM funcionarios)
 WHERE faixa IS NULL;

-- 6. Agregação condicional: contagem por status numa linha.
-- Esperado: abertos 3 | faturados 3 | entregues 17 | cancelados 1
SELECT COUNT(CASE WHEN status = 'ABERTO'    THEN 1 END) AS abertos,
       COUNT(CASE WHEN status = 'FATURADO'  THEN 1 END) AS faturados,
       COUNT(CASE WHEN status = 'ENTREGUE'  THEN 1 END) AS entregues,
       COUNT(CASE WHEN status = 'CANCELADO' THEN 1 END) AS cancelados
  FROM pedidos;

-- A armadilha do ELSE 0 dentro de COUNT.
-- Esperado: 24 (conta todas as linhas) | 3 (SUM conta só os 1)
SELECT COUNT(CASE WHEN status = 'ABERTO' THEN 1 ELSE 0 END) AS count_errado,
       SUM  (CASE WHEN status = 'ABERTO' THEN 1 ELSE 0 END) AS sum_certo
  FROM pedidos;

-- 7. CASE simples não reconhece NULL; CASE pesquisado sim.
SELECT nome,
       CASE pct_comissao WHEN NULL THEN 'sem' ELSE 'com' END        AS simples_errado,
       CASE WHEN pct_comissao IS NULL THEN 'sem' ELSE 'com' END     AS pesquisado_certo
  FROM funcionarios
 WHERE id_funcionario IN (100, 104);
-- 100: simples diz "com" (errado), pesquisado diz "sem"

-- 8. CASE no UPDATE: reajustes diferentes por categoria num comando.
-- Esperado: 13 = 867.9, 14 = 317.9 (Cadeiras +10%), 8 = 33.48 (Papelaria +3%)
UPDATE produtos
   SET preco_unitario = ROUND(CASE id_categoria
                                  WHEN 7 THEN preco_unitario * 1.10
                                  WHEN 5 THEN preco_unitario * 1.03
                                  ELSE preco_unitario
                              END, 2);

SELECT id_produto, nome, preco_unitario
  FROM produtos
 WHERE id_produto IN (8, 13, 14)
 ORDER BY id_produto;

ROLLBACK;
