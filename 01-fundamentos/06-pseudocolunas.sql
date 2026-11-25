-- =============================================================================
-- Tópico : Pseudocolunas — ROWNUM, ROWID, LEVEL, ORA_ROWSCN
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. ROWNUM é atribuído antes do ORDER BY.
--    Errado: três linhas quaisquer, ordenadas depois.
SELECT ROWNUM AS rn, nome, salario
  FROM funcionarios
 WHERE ROWNUM <= 3
 ORDER BY salario DESC;

-- Certo: ordenar primeiro, numerar depois.
SELECT ROWNUM AS rn, nome, salario
  FROM (SELECT nome, salario FROM funcionarios ORDER BY salario DESC)
 WHERE ROWNUM <= 3;
-- 1 Ana Ribeiro    25000
-- 2 Bruno Carvalho 14000
-- 3 Carla Mendes   13500

-- Equivalente moderno (seção 02).
SELECT nome, salario
  FROM funcionarios
 ORDER BY salario DESC
 FETCH FIRST 3 ROWS ONLY;

-- 2. ROWNUM = 2 (ou > 1) nunca devolve nada.
-- Esperado: 0
SELECT COUNT(*) AS linhas FROM funcionarios WHERE ROWNUM = 2;

-- Para "a segunda linha", numerar numa subquery e filtrar fora.
-- Esperado: Bruno Carvalho
SELECT nome, salario
  FROM (SELECT nome, salario, ROWNUM AS rn
          FROM (SELECT nome, salario FROM funcionarios ORDER BY salario DESC))
 WHERE rn = 2;

-- 3. ROWID: endereço físico da linha.
SELECT ROWID, id_cliente, nome
  FROM clientes
 WHERE ROWNUM <= 3;

-- Decompondo o ROWID com DBMS_ROWID.
SELECT id_cliente,
       DBMS_ROWID.ROWID_OBJECT(ROWID)       AS objeto,
       DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID) AS arquivo,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS bloco,
       DBMS_ROWID.ROWID_ROW_NUMBER(ROWID)   AS linha_no_bloco
  FROM clientes
 WHERE id_cliente <= 3;

-- Acesso por ROWID: no plano aparece TABLE ACCESS BY USER ROWID.
EXPLAIN PLAN FOR
SELECT nome FROM clientes WHERE ROWID = (SELECT ROWID FROM clientes WHERE id_cliente = 1);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 4. LEVEL como gerador de linhas: os 12 meses de 2026.
SELECT LEVEL                                              AS mes,
       TO_CHAR(ADD_MONTHS(DATE '2026-01-01', LEVEL - 1), 'YYYY-MM') AS competencia
  FROM dual
CONNECT BY LEVEL <= 12;

-- LEVEL numa hierarquia: organograma a partir da diretoria.
SELECT LEVEL AS nivel,
       LPAD(' ', (LEVEL - 1) * 2) || nome AS organograma,
       cargo
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente
 ORDER SIBLINGS BY nome;
-- nível máximo: 4 (Ana > Bruno > Isabela > vendedores)

-- 5. ORA_ROWSCN: muda depois de uma alteração confirmada.
SELECT id_cliente, ORA_ROWSCN FROM clientes WHERE id_cliente = 12;

UPDATE clientes SET limite_credito = limite_credito WHERE id_cliente = 12;
COMMIT;

-- Esperado: valor maior
SELECT id_cliente, ORA_ROWSCN FROM clientes WHERE id_cliente = 12;

-- 6. SYSDATE (relógio do servidor) versus CURRENT_DATE (fuso da sessão).
ALTER SESSION SET TIME_ZONE = 'America/Sao_Paulo';

SELECT TO_CHAR(SYSDATE,      'YYYY-MM-DD HH24:MI') AS servidor,
       TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI') AS sessao,
       SESSIONTIMEZONE                             AS fuso_sessao
  FROM dual;
-- Num container com fuso UTC, a diferença é de 3 horas.
