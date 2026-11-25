-- =============================================================================
-- Tópico : CONNECT BY — consultas hierárquicas
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Organograma de cima para baixo, com recuo por nível e irmãos em ordem.
-- Esperado: 14 linhas; Ana no nível 1, vendedores de Isabela no nível 4
SELECT LEVEL                                   AS nivel,
       LPAD(' ', (LEVEL - 1) * 3) || nome      AS organograma,
       cargo,
       SYS_CONNECT_BY_PATH(nome, ' > ')        AS caminho,
       CONNECT_BY_ISLEAF                       AS folha
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente
 ORDER SIBLINGS BY nome;

-- 2. De baixo para cima: a cadeia de chefia de um vendedor.
-- Esperado: Eduarda Lima, Isabela Costa, Bruno Carvalho, Ana Ribeiro
SELECT LEVEL AS distancia, nome, cargo
  FROM funcionarios
 START WITH id_funcionario = 104
CONNECT BY id_funcionario = PRIOR id_gerente;

-- 3. ORDER BY comum desmonta a árvore; compare com o exemplo 1.
SELECT LEVEL AS nivel, LPAD(' ', (LEVEL - 1) * 3) || nome AS organograma
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente
 ORDER BY nome;

-- 4. Total de subordinados (todos os níveis) de cada gestor.
--    Sem START WITH, cada funcionário é raiz da própria árvore.
--    LEVEL > 1 descarta a própria raiz da contagem.
-- Esperado: 100 = 13, 101 = 6, 108 = 3, 102 = 2, 103 = 2, 109 = 1, 111 = 1
SELECT id_gestor, gestor, COUNT(*) AS subordinados
  FROM (SELECT CONNECT_BY_ROOT id_funcionario AS id_gestor,
               CONNECT_BY_ROOT nome           AS gestor
          FROM funcionarios
         WHERE LEVEL > 1
       CONNECT BY PRIOR id_funcionario = id_gerente)
 GROUP BY id_gestor, gestor
 ORDER BY subordinados DESC, id_gestor;

-- 5. Árvore de categorias: caminho e categoria raiz de cada uma.
SELECT id_categoria,
       LPAD(' ', (LEVEL - 1) * 3) || nome          AS categoria,
       LTRIM(SYS_CONNECT_BY_PATH(nome, ' / '), ' / ') AS caminho,
       CONNECT_BY_ROOT nome                         AS raiz,
       CONNECT_BY_ISLEAF                            AS folha
  FROM categorias
 START WITH id_categoria_pai IS NULL
CONNECT BY PRIOR id_categoria = id_categoria_pai
 ORDER SIBLINGS BY nome;

-- 6. Produtos por categoria raiz (subindo a árvore a partir de cada produto).
-- Esperado: Escritorio 7, Informatica 8
--    O WHERE da subquery é aplicado depois do percurso: sobra só a raiz.
SELECT raiz, COUNT(*) AS produtos
  FROM (SELECT p.id_produto,
               (SELECT c.nome
                  FROM categorias c
                 WHERE c.id_categoria_pai IS NULL
                 START WITH c.id_categoria = p.id_categoria
               CONNECT BY c.id_categoria = PRIOR c.id_categoria_pai) AS raiz
          FROM produtos p)
 GROUP BY raiz
 ORDER BY raiz;

-- 7. Filtro no WHERE versus no CONNECT BY.
--    WHERE: tira só a Isabela (108); os vendedores dela continuam.
-- Esperado: 13
SELECT COUNT(*) AS filtro_where
  FROM funcionarios
 WHERE id_funcionario <> 108
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente;

--    CONNECT BY: corta o ramo inteiro da Isabela.
-- Esperado: 10
SELECT COUNT(*) AS filtro_connect_by
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente
       AND id_funcionario <> 108;

-- 8. Gerador de linhas: os 7 dias a partir de hoje.
SELECT TRUNC(SYSDATE) + LEVEL - 1                           AS dia,
       TO_CHAR(TRUNC(SYSDATE) + LEVEL - 1, 'DY', 'NLS_DATE_LANGUAGE = PORTUGUESE') AS dia_semana
  FROM dual
CONNECT BY LEVEL <= 7;

-- 9. Ciclo nos dados: erro sem NOCYCLE, marcação com NOCYCLE.
CREATE TABLE tmp_rede (id NUMBER, id_pai NUMBER);
INSERT INTO tmp_rede VALUES (1, 3);
INSERT INTO tmp_rede VALUES (2, 1);
INSERT INTO tmp_rede VALUES (3, 2);
COMMIT;

-- Esperado: ORA-01436 (loop de CONNECT BY nos dados do usuário)
SELECT id, LEVEL
  FROM tmp_rede
 START WITH id = 1
CONNECT BY PRIOR id = id_pai;

-- Esperado: 3 linhas; a do id 3 com ciclo = 1 (o próximo passo voltaria ao 1)
SELECT id, LEVEL, CONNECT_BY_ISCYCLE AS ciclo
  FROM tmp_rede
 START WITH id = 1
CONNECT BY NOCYCLE PRIOR id = id_pai;

DROP TABLE tmp_rede PURGE;
