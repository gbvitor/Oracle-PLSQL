-- =============================================================================
-- Tópico : DUAL e consultas sem tabela
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : qualquer conexão
-- =============================================================================

-- 1. Estrutura e conteúdo: uma coluna, uma linha.
-- Esperado: DUMMY = X
SELECT * FROM dual;

-- 2. Avaliar expressões e funções.
SELECT 17 / 4                                AS divisao,          -- 4.25
       TRUNC(17 / 4)                         AS parte_inteira,    -- 4
       MOD(17, 4)                            AS resto,            -- 1
       UPPER('consulta sem tabela')          AS maiusculas,
       TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI') AS agora
  FROM dual;

-- 3. Contexto da sessão.
SELECT USER                                   AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME')     AS container,
       SYS_CONTEXT('USERENV', 'NLS_DATE_FORMAT') AS formato_data
  FROM dual;

-- 4. Lista de valores fixos usada como tabela.
--    Útil para conferir uma lista de códigos contra o banco.
WITH codigos AS (
    SELECT 1  AS id_produto FROM dual UNION ALL
    SELECT 15 FROM dual UNION ALL
    SELECT 99 FROM dual
)
SELECT c.id_produto,
       NVL(p.nome, '(nao cadastrado)') AS nome
  FROM codigos c
  LEFT JOIN produtos p ON p.id_produto = c.id_produto
 ORDER BY c.id_produto;
-- 1  Mouse optico USB
-- 15 Hub USB 4 portas
-- 99 (nao cadastrado)

-- 5. O plano de execução mostra que DUAL não é lida.
EXPLAIN PLAN FOR SELECT SYSDATE FROM dual;
-- Esperado: operação FAST DUAL
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC'));

-- 6. [23ai+] FROM opcional. Em 19c, este comando dá ORA-00923.
-- SELECT SYSDATE, 2 + 2
