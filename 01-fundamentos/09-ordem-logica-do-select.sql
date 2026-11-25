-- =============================================================================
-- Tópico : Ordem lógica de execução do SELECT
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Cada bloco mostra o erro causado pela ordem lógica e a forma correta.
-- =============================================================================

-- 1. Alias criado no SELECT não existe no WHERE.
-- Esperado: ORA-00904 ("ANUAL": identificador inválido)
SELECT nome, salario * 12 AS anual
  FROM funcionarios
 WHERE anual > 100000;

-- Correto: repetir a expressão no WHERE. O alias funciona no ORDER BY.
-- Esperado: 4 linhas (100, 101, 102, 103)
SELECT nome, salario * 12 AS anual
  FROM funcionarios
 WHERE salario * 12 > 100000
 ORDER BY anual DESC;

-- 2. Agregação no WHERE: os grupos ainda não existem.
-- Esperado: ORA-00934 (função de grupo não é permitida aqui)
SELECT id_departamento, AVG(salario)
  FROM funcionarios
 WHERE AVG(salario) > 7000
 GROUP BY id_departamento;

-- Correto: filtro sobre grupo vai no HAVING.
-- Esperado: departamentos 10 (25000) e 30 (7766.67)
SELECT id_departamento, ROUND(AVG(salario), 2) AS media_salarial
  FROM funcionarios
 GROUP BY id_departamento
HAVING AVG(salario) > 7000
 ORDER BY id_departamento;

-- 3. Função analítica no WHERE: só é calculada no SELECT.
-- Esperado: ORA-30483 (funções de janela não são permitidas aqui)
SELECT nome, salario
  FROM funcionarios
 WHERE RANK() OVER (ORDER BY salario DESC) <= 3;

-- Correto: calcular num nível e filtrar no de fora.
-- Esperado: Ana Ribeiro, Bruno Carvalho, Carla Mendes
SELECT nome, salario, posicao
  FROM (SELECT nome,
               salario,
               RANK() OVER (ORDER BY salario DESC) AS posicao
          FROM funcionarios)
 WHERE posicao <= 3
 ORDER BY posicao;

-- 4. A função analítica enxerga as linhas que sobraram do WHERE.
-- Esperado: total_no_resultado = 6 em todas as linhas (só o Comercial)
SELECT nome,
       COUNT(*) OVER () AS total_no_resultado
  FROM funcionarios
 WHERE id_departamento = 20;

-- 5. Depois do DISTINCT, só existem as colunas selecionadas.
-- Esperado: ORA-01791 (não é uma expressão selecionada)
SELECT DISTINCT cargo
  FROM funcionarios
 ORDER BY salario DESC;

-- Correto: agrupar e ordenar por uma agregação.
SELECT cargo, MAX(salario) AS maior_salario
  FROM funcionarios
 GROUP BY cargo
 ORDER BY maior_salario DESC;

-- 6. Alias no GROUP BY: não aceito no 19c ([23ai+] aceita).
-- Esperado no 19c: ORA-00904 ("ANO": identificador inválido)
SELECT EXTRACT(YEAR FROM data_pedido) AS ano, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY ano;

-- Correto em qualquer versão: repetir a expressão.
-- Esperado: 2025 = 16 pedidos, 2026 = 8 pedidos
SELECT EXTRACT(YEAR FROM data_pedido) AS ano, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY EXTRACT(YEAR FROM data_pedido)
 ORDER BY ano;

-- 7. Hierarquia: o WHERE é aplicado depois de montar a árvore.
--    Tirar a supervisora (108) no WHERE remove só a linha dela;
--    os vendedores subordinados continuam.
-- Esperado: 13
SELECT COUNT(*) AS filtrando_no_where
  FROM funcionarios
 WHERE id_funcionario <> 108
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente;

-- Condição no CONNECT BY poda o ramo inteiro (108 e seus 3 vendedores).
-- Esperado: 10
SELECT COUNT(*) AS podando_no_connect_by
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente
       AND id_funcionario <> 108;
